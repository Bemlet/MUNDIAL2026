package com.ever.mundial2026

import android.content.Context
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.TimeUnit

/**
 * Lógica compartida de sincronización en vivo: baja el scoreboard de ESPN,
 * detecta goles/finales/recordatorios y postea notificaciones. La usan tanto
 * el [LiveSyncWorker] (periódico, 15 min) como el [LiveMatchService]
 * (foreground, ~45 s mientras hay partidos en vivo).
 */
object LiveSyncCore {
    const val ESPN_URL =
        "https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/scoreboard?dates=20260611-20260719&limit=200"
    const val FIFTEEN_MINUTES_MS = 15 * 60 * 1000L

    /** Ejecuta una pasada. Devuelve true si algún partido está en vivo ahora. */
    fun run(context: Context): Boolean {
        val matches = loadMatches(context)
        val teams = loadTeams(context)
        val events = JSONObject(fetchScoreboard()).getJSONArray("events")
        val seenStatuses = mutableMapOf<String, MatchStatus>()
        var anyLive = false

        for (i in 0 until events.length()) {
            val event = events.getJSONObject(i)
            val id = event.optString("id")
            val match = matches[id] ?: continue
            val statusType = event.optJSONObject("status")?.optJSONObject("type")
            val status = statusType?.optString("name").orEmpty()
            val state = statusType?.optString("state").orEmpty()
            val displayClock = event.optJSONObject("status")?.optString("displayClock").orEmpty()
            val shortDetail = statusType?.optString("shortDetail").orEmpty()
            val detail = if (state == "in" && displayClock.isNotBlank()) displayClock else shortDetail
            val competition = event.getJSONArray("competitions").getJSONObject(0)
            val competitors = competition.getJSONArray("competitors")
            var homeName = ""
            var awayName = ""
            var homeScore: Int? = null
            var awayScore: Int? = null

            for (j in 0 until competitors.length()) {
                val competitor = competitors.getJSONObject(j)
                val teamName = competitor.optJSONObject("team")?.optString("displayName").orEmpty()
                val score = competitor.optString("score").toIntOrNull()
                if (competitor.optString("homeAway") == "home") {
                    homeName = teamName
                    homeScore = score
                } else {
                    awayName = teamName
                    awayScore = score
                }
            }

            val current = MatchStatus(
                match = match,
                homeEspn = homeName,
                awayEspn = awayName,
                homeScore = homeScore,
                awayScore = awayScore,
                status = status,
                detail = detail,
            )
            seenStatuses[id] = current
            if (current.isLive) anyLive = true
            processLiveNotifications(context, current, teams)
        }

        checkKickoffReminders(context, matches.values, seenStatuses, teams)
        return anyLive
    }

    private fun processLiveNotifications(context: Context, status: MatchStatus, teams: TeamLookup) {
        val prefs = NotificationHelper.prefs(context)
        val match = status.match
        val total = status.totalScore() ?: return
        val previousTotal = prefs.getInt("score_${match.espnId}", -1)
        val previousFinished = prefs.getBoolean("finished_${match.espnId}", false)

        if (status.isLive && total > 0 && (previousTotal == -1 || total > previousTotal)) {
            NotificationHelper.notifyOnce(
                context,
                "goal_${match.no}_${status.homeScore}_${status.awayScore}",
                200000 + match.no * 10 + total,
                "${strings(context).goalIn} ${matchName(context, status, teams)}",
                scoreBody(context, status, teams),
            )
        }

        if (!previousFinished && previousTotal != -1 && status.isFinished) {
            NotificationHelper.notifyOnce(
                context,
                "final_${match.no}",
                300000 + match.no,
                strings(context).fullTime,
                scoreBody(context, status, teams),
            )
        }

        prefs.edit()
            .putInt("score_${match.espnId}", total)
            .putBoolean("finished_${match.espnId}", status.isFinished)
            .apply()
    }

    private fun checkKickoffReminders(
        context: Context,
        matches: Collection<MatchInfo>,
        statuses: Map<String, MatchStatus>,
        teams: TeamLookup,
    ) {
        val now = System.currentTimeMillis()
        for (match in matches) {
            val status = statuses[match.espnId]
            if (status?.isLive == true || status?.isFinished == true) continue
            val untilKickoff = match.dateMillis - now
            if (untilKickoff < 0 || untilKickoff > FIFTEEN_MINUTES_MS) continue
            val minutes = TimeUnit.MILLISECONDS.toMinutes(untilKickoff).toInt()
            val text = if (minutes <= 1) strings(context).inMoments else strings(context).inMinutes(minutes)
            NotificationHelper.notifyOnce(
                context,
                "start_${match.no}",
                100000 + match.no,
                strings(context).matchStarting,
                "${matchName(context, match, teams)} ${strings(context).starts(text)}",
            )
        }
    }

    /** Texto "Local vs Visitante" para un partido (usado por recordatorios). */
    fun reminderBody(context: Context, matchNo: Int): String? {
        val teams = loadTeams(context)
        val match = loadMatches(context).values.firstOrNull { it.no == matchNo } ?: return null
        val text = strings(context).inMinutes(15)
        return "${matchName(context, match, teams)} ${strings(context).starts(text)}"
    }

    fun matchInfos(context: Context): Collection<MatchInfo> = loadMatches(context).values

    private fun matchName(context: Context, status: MatchStatus, teams: TeamLookup): String {
        return "${teamName(context, status.match.homeSlot, status.homeEspn, teams)} vs ${teamName(context, status.match.awaySlot, status.awayEspn, teams)}"
    }

    private fun matchName(context: Context, match: MatchInfo, teams: TeamLookup): String {
        return "${teamName(context, match.homeSlot, "", teams)} vs ${teamName(context, match.awaySlot, "", teams)}"
    }

    private fun scoreBody(context: Context, status: MatchStatus, teams: TeamLookup): String {
        val base = if (status.homeScore == null || status.awayScore == null) {
            matchName(context, status, teams)
        } else {
            "${teamName(context, status.match.homeSlot, status.homeEspn, teams)} ${status.homeScore} - ${status.awayScore} ${teamName(context, status.match.awaySlot, status.awayEspn, teams)}"
        }
        return if (status.detail.isBlank()) base else "$base · ${status.detail}"
    }

    private fun teamName(context: Context, slot: String, espnName: String, teams: TeamLookup): String {
        val language = NotificationHelper.language(context)
        val espnTeam = teams.byEspn[espnName]
        if (espnTeam != null) return espnTeam.name(language)
        val slotTeam = teams.byId[slot]
        if (slotTeam != null) return slotTeam.name(language)
        return if (espnName.isNotBlank()) espnName else slotLabel(slot, language)
    }

    fun strings(context: Context): WorkerStrings {
        return if (NotificationHelper.language(context) == "en") WorkerStrings.en else WorkerStrings.es
    }

    private fun loadMatches(context: Context): Map<String, MatchInfo> {
        val json = JSONObject(readFlutterAsset(context, "assets/data/matches.json"))
        val array = json.getJSONArray("matches")
        val result = mutableMapOf<String, MatchInfo>()
        for (i in 0 until array.length()) {
            val item = array.getJSONObject(i)
            val espnId = item.optString("espnId")
            result[espnId] = MatchInfo(
                no = item.getInt("no"),
                espnId = espnId,
                dateMillis = parseUtcDate(item.getString("date")),
                homeSlot = item.getString("home"),
                awaySlot = item.getString("away"),
            )
        }
        return result
    }

    private fun parseUtcDate(value: String): Long {
        val parser = SimpleDateFormat("yyyy-MM-dd'T'HH:mmX", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
        return parser.parse(value)?.time ?: 0L
    }

    private fun loadTeams(context: Context): TeamLookup {
        val json = JSONObject(readFlutterAsset(context, "assets/data/teams.json"))
        val array = json.getJSONArray("teams")
        val byId = mutableMapOf<String, TeamInfo>()
        val byEspn = mutableMapOf<String, TeamInfo>()
        for (i in 0 until array.length()) {
            val item = array.getJSONObject(i)
            val team = TeamInfo(
                id = item.getString("id"),
                nameEs = item.getString("name"),
                nameEn = item.getString("espn"),
            )
            byId[team.id] = team
            byEspn[team.nameEn] = team
        }
        return TeamLookup(byId, byEspn)
    }

    private fun readFlutterAsset(context: Context, path: String): String {
        val candidates = listOf("flutter_assets/$path", path)
        for (candidate in candidates) {
            try {
                return context.assets.open(candidate).bufferedReader().use { it.readText() }
            } catch (_: Exception) {
            }
        }
        throw IllegalStateException("Asset not found: $path")
    }

    private fun fetchScoreboard(): String {
        val connection = (URL(ESPN_URL).openConnection() as HttpURLConnection).apply {
            connectTimeout = 15000
            readTimeout = 15000
            requestMethod = "GET"
        }
        return connection.inputStream.bufferedReader().use { it.readText() }
    }

    private fun slotLabel(slot: String, language: String): String {
        if (slot.length == 2 && slot.startsWith("W")) {
            return if (language == "en") "Winner Group ${slot[1]}" else "1.º Grupo ${slot[1]}"
        }
        if (slot.length == 2 && slot.startsWith("R")) {
            return if (language == "en") "Runner-up Group ${slot[1]}" else "2.º Grupo ${slot[1]}"
        }
        if (slot.startsWith("T")) {
            val groups = slot.substring(1).toCharArray().joinToString("/")
            return if (language == "en") "3rd $groups" else "3.º $groups"
        }
        if (slot.startsWith("M")) {
            return if (language == "en") "Winner M${slot.substring(1)}" else "Ganador P${slot.substring(1)}"
        }
        if (slot.startsWith("L")) {
            return if (language == "en") "Loser M${slot.substring(1)}" else "Perdedor P${slot.substring(1)}"
        }
        return slot
    }
}

data class MatchInfo(
    val no: Int,
    val espnId: String,
    val dateMillis: Long,
    val homeSlot: String,
    val awaySlot: String,
)

private data class TeamInfo(val id: String, val nameEs: String, val nameEn: String) {
    fun name(language: String) = if (language == "en") nameEn else nameEs
}

private data class TeamLookup(
    val byId: Map<String, TeamInfo>,
    val byEspn: Map<String, TeamInfo>,
)

private data class MatchStatus(
    val match: MatchInfo,
    val homeEspn: String,
    val awayEspn: String,
    val homeScore: Int?,
    val awayScore: Int?,
    val status: String,
    val detail: String,
) {
    val isLive: Boolean
        get() = status.contains("IN_PROGRESS") ||
            status.contains("HALFTIME") ||
            status.contains("FIRST_HALF") ||
            status.contains("SECOND_HALF") ||
            status.contains("EXTRA_TIME") ||
            status.contains("SHOOTOUT")

    val isFinished: Boolean
        get() = status.contains("FINAL") || status.contains("FULL_TIME") || status == "STATUS_FT"

    fun totalScore(): Int? {
        val home = homeScore ?: return null
        val away = awayScore ?: return null
        return home + away
    }
}

data class WorkerStrings(
    val goalIn: String,
    val fullTime: String,
    val matchStarting: String,
    val inMoments: String,
    val inMinutes: (Int) -> String,
    val starts: (String) -> String,
) {
    companion object {
        val es = WorkerStrings(
            goalIn = "Gol en",
            fullTime = "Partido finalizado",
            matchStarting = "Partido por comenzar",
            inMoments = "en instantes",
            inMinutes = { "en $it min" },
            starts = { "arranca $it." },
        )
        val en = WorkerStrings(
            goalIn = "Goal in",
            fullTime = "Full time",
            matchStarting = "Match starting soon",
            inMoments = "in moments",
            inMinutes = { "in $it min" },
            starts = { "starts $it." },
        )
    }
}
