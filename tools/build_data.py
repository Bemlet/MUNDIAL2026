#!/usr/bin/env python3
"""Genera assets/data/teams.json y assets/data/matches.json para la app.

Combina:
 - espn_events.json (IDs ESPN, kickoff UTC exacto, estadio) descargado de la API publica de ESPN
 - fixture transcrito de Wikipedia (numeros de partido, grupos, reglas del bracket)
"""
import json, os, sys, unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ESPN = json.load(open(os.path.expanduser('~/espn_events.json')))

# ---------------------------------------------------------------- equipos
# id, nombre ES, nombre ESPN, bandera, grupo, confederacion, ranking FIFA (nov 2025, aprox),
# participaciones (incluida 2026), titulos, mejor resultado, figuras, nota
T = [
 ('MEX','México','Mexico','mx','A','CONCACAF',14,18,0,'Cuartos de final (1970, 1986)',['Raúl Jiménez','Edson Álvarez','Gilberto Mora'],'Anfitrión por tercera vez en su historia: ningún país ha organizado más Mundiales. Abrió el torneo en el Azteca con triunfo.'),
 ('RSA','Sudáfrica','South Africa','za','A','CAF',61,4,0,'Fase de grupos',['Ronwen Williams','Percy Tau','Teboho Mokoena'],'Los Bafana Bafana vuelven a un Mundial que no organizan por primera vez desde 2002.'),
 ('KOR','Corea del Sur','South Korea','kr','A','AFC',22,12,0,'Cuarto puesto (2002)',['Son Heung-min','Lee Kang-in','Kim Min-jae'],'Undécima participación consecutiva, racha que solo superan las grandes potencias.'),
 ('CZE','Chequia','Czechia','cz','A','UEFA',43,3,0,'Subcampeón como Checoslovaquia (1934, 1962)',['Patrik Schick','Tomáš Souček','Adam Hložek'],'Primera clasificación como República Checa desde 2006; heredera de la histórica Checoslovaquia.'),
 ('CAN','Canadá','Canada','ca','B','CONCACAF',27,3,0,'Fase de grupos',['Alphonso Davies','Jonathan David','Stephen Eustáquio'],'Coanfitrión y con su mejor generación histórica; busca su primera victoria mundialista en casa.'),
 ('BIH','Bosnia y Herzegovina','Bosnia-Herzegovina','ba','B','UEFA',75,2,0,'Fase de grupos (2014)',['Edin Džeko','Ermedin Demirović','Sead Kolašinac'],'Regresa al Mundial 12 años después de su debut en Brasil 2014.'),
 ('QAT','Catar','Qatar','qa','B','AFC',53,2,0,'Fase de grupos (2022)',['Akram Afif','Almoez Ali','Hassan Al-Haydos'],'Primera vez que se clasifica por la vía deportiva, tras organizar el Mundial 2022.'),
 ('SUI','Suiza','Switzerland','ch','B','UEFA',17,13,0,'Cuartos de final (1934, 1938, 1954)',['Granit Xhaka','Manuel Akanji','Breel Embolo'],'Sexto Mundial consecutivo; habitual de octavos en las últimas ediciones.'),
 ('BRA','Brasil','Brazil','br','C','CONMEBOL',5,23,5,'Campeón (1958, 1962, 1970, 1994, 2002)',['Vinícius Júnior','Rodrygo','Estêvão'],'El único país presente en los 23 Mundiales y máximo campeón con cinco estrellas. Ahora dirigido por Carlo Ancelotti.'),
 ('MAR','Marruecos','Morocco','ma','C','CAF',11,7,0,'Cuarto puesto (2022)',['Achraf Hakimi','Brahim Díaz','Azzedine Ounahi'],'Hizo historia en 2022 como la primera semifinalista africana; llega como líder del continente.'),
 ('SCO','Escocia','Scotland','gb-sct','C','UEFA',38,9,0,'Fase de grupos',['Scott McTominay','Andy Robertson','John McGinn'],'Vuelve a un Mundial tras 28 años de ausencia: su última cita fue Francia 1998.'),
 ('HAI','Haití','Haiti','ht','C','CONCACAF',84,2,0,'Fase de grupos (1974)',['Duckens Nazon','Frantzdy Pierrot','Danley Jean Jacques'],'Su segunda participación, 52 años después de su debut en Alemania 1974.'),
 ('USA','Estados Unidos','United States','us','D','CONCACAF',16,12,0,'Semifinales (1930)',['Christian Pulisic','Weston McKennie','Antonee Robinson'],'Anfitrión principal: organiza 78 de los 104 partidos, incluida la final.'),
 ('PAR','Paraguay','Paraguay','py','D','CONMEBOL',39,9,0,'Cuartos de final (2010)',['Miguel Almirón','Julio Enciso','Gustavo Gómez'],'La Albirroja regresa tras 16 años; no jugaba un Mundial desde Sudáfrica 2010.'),
 ('AUS','Australia','Australia','au','D','AFC',26,7,0,'Octavos de final (2006, 2022)',['Mathew Ryan','Jackson Irvine','Craig Goodwin'],'Sexto Mundial consecutivo de los Socceroos.'),
 ('TUR','Turquía','Türkiye','tr','D','UEFA',25,3,0,'Tercer puesto (2002)',['Arda Güler','Hakan Çalhanoğlu','Kenan Yıldız'],'Regresa tras 24 años con una generación dorada liderada por Arda Güler.'),
 ('GER','Alemania','Germany','de','E','UEFA',9,21,4,'Campeón (1954, 1974, 1990, 2014)',['Jamal Musiala','Florian Wirtz','Joshua Kimmich'],'Cuatro veces campeona; busca redimirse tras dos eliminaciones seguidas en fase de grupos.'),
 ('CUW','Curazao','Curaçao','cw','E','CONCACAF',82,1,0,'Debut',['Leandro Bacuna','Juninho Bacuna','Eloy Room'],'El país más pequeño en la historia de los Mundiales: ~156.000 habitantes. Debutante absoluto.'),
 ('CIV','Costa de Marfil','Ivory Coast','ci','E','CAF',46,4,0,'Fase de grupos',['Franck Kessié','Amad Diallo','Seko Fofana'],'Campeón de África 2024; cuarta participación mundialista de los Elefantes.'),
 ('ECU','Ecuador','Ecuador','ec','E','CONMEBOL',23,5,0,'Octavos de final (2006)',['Moisés Caicedo','Piero Hincapié','Kendry Páez'],'Hizo una eliminatoria sobresaliente: segunda de Sudamérica solo detrás de Argentina.'),
 ('NED','Países Bajos','Netherlands','nl','F','UEFA',7,12,0,'Subcampeón (1974, 1978, 2010)',['Virgil van Dijk','Cody Gakpo','Xavi Simons'],'La eterna candidata: tres finales jugadas, ninguna ganada. La Naranja Mecánica busca su primera estrella.'),
 ('JPN','Japón','Japan','jp','F','AFC',19,8,0,'Octavos de final (2002, 2010, 2018, 2022)',['Takefusa Kubo','Kaoru Mitoma','Wataru Endo'],'Fue la primera selección clasificada para 2026. Sueña con romper por fin la barrera de octavos.'),
 ('SWE','Suecia','Sweden','se','F','UEFA',40,13,0,'Subcampeón (1958)',['Alexander Isak','Viktor Gyökeres','Dejan Kulusevski'],'Regresa tras ganar el repechaje; su dupla Isak-Gyökeres es de las más temidas de Europa.'),
 ('TUN','Túnez','Tunisia','tn','F','CAF',41,7,0,'Fase de grupos',['Hannibal Mejbri','Youssef Msakni','Aïssa Laïdouni'],'Tercer Mundial consecutivo de las Águilas de Cartago.'),
 ('BEL','Bélgica','Belgium','be','G','UEFA',8,15,0,'Tercer puesto (2018)',['Kevin De Bruyne','Jérémy Doku','Romelu Lukaku'],'La generación dorada dio paso a una nueva camada liderada por Doku.'),
 ('EGY','Egipto','Egypt','eg','G','CAF',34,4,0,'Fase de grupos',['Mohamed Salah','Omar Marmoush','Mohamed Elneny'],'Salah, leyenda del Liverpool, disputa probablemente su último Mundial.'),
 ('IRN','Irán','Iran','ir','G','AFC',21,7,0,'Fase de grupos',['Mehdi Taremi','Sardar Azmoun','Alireza Jahanbakhsh'],'Cuarto Mundial consecutivo; nunca ha superado la primera fase.'),
 ('NZL','Nueva Zelanda','New Zealand','nz','G','OFC',85,3,0,'Fase de grupos (invicto en 2010)',['Chris Wood','Liberato Cacace','Marko Stamenic'],'El único representante de Oceanía; en 2010 se fue invicto sin ganar un partido.'),
 ('ESP','España','Spain','es','H','UEFA',1,17,1,'Campeón (2010)',['Lamine Yamal','Pedri','Nico Williams'],'Número 1 del ranking FIFA y campeona de Europa 2024. La gran favorita junto a Argentina y Francia.'),
 ('CPV','Cabo Verde','Cape Verde','cv','H','CAF',70,1,0,'Debut',['Ryan Mendes','Jamiro Monteiro','Bebé'],'Debutante histórico: el archipiélago de ~525.000 habitantes logró una clasificación épica.'),
 ('KSA','Arabia Saudita','Saudi Arabia','sa','H','AFC',60,7,0,'Octavos de final (1994)',['Salem Al-Dawsari','Firas Al-Buraikan','Saud Abdulhamid'],'En 2022 protagonizó la sorpresa del torneo al vencer a la Argentina campeona.'),
 ('URU','Uruguay','Uruguay','uy','H','CONMEBOL',15,15,2,'Campeón (1930, 1950)',['Federico Valverde','Darwin Núñez','Rodrigo Bentancur'],'Dos veces campeona del mundo; la Celeste de Bielsa fue tercera en la eliminatoria sudamericana.'),
 ('FRA','Francia','France','fr','I','UEFA',3,17,2,'Campeón (1998, 2018)',['Kylian Mbappé','Ousmane Dembélé','Aurélien Tchouaméni'],'Finalista en 2022 y campeona en dos de los últimos tres Mundiales. Dembélé llega como Balón de Oro 2025.'),
 ('SEN','Senegal','Senegal','sn','I','CAF',18,4,0,'Cuartos de final (2002)',['Sadio Mané','Nicolas Jackson','Iliman Ndiaye'],'La mejor selección africana del ranking junto a Marruecos.'),
 ('IRQ','Irak','Iraq','iq','I','AFC',58,2,0,'Fase de grupos (1986)',['Aymen Hussein','Ali Al-Hamadi','Ibrahim Bayesh'],'Vuelve a un Mundial 40 años después de México 1986; ganó el repechaje asiático.'),
 ('NOR','Noruega','Norway','no','I','UEFA',29,4,0,'Octavos de final (1998)',['Erling Haaland','Martin Ødegaard','Alexander Sørloth'],'Clasificó con puntaje perfecto y Haaland en modo récord: 16 goles en la eliminatoria.'),
 ('ARG','Argentina','Argentina','ar','J','CONMEBOL',2,19,3,'Campeón (1978, 1986, 2022)',['Lionel Messi','Julián Álvarez','Lautaro Martínez'],'Defensora del título. Messi, a sus 38 años, disputa su sexto Mundial: nadie ha jugado más.'),
 ('ALG','Argelia','Algeria','dz','J','CAF',36,5,0,'Octavos de final (2014)',['Riyad Mahrez','Amine Gouiri','Houssem Aouar'],'Los Zorros del Desierto vuelven tras perderse Catar 2022.'),
 ('AUT','Austria','Austria','at','J','UEFA',24,8,0,'Tercer puesto (1954)',['David Alaba','Marcel Sabitzer','Christoph Baumgartner'],'Primera clasificación desde 1998; el equipo de Rangnick presiona como ninguno.'),
 ('JOR','Jordania','Jordan','jo','J','AFC',64,1,0,'Debut',['Mousa Al-Taamari','Yazan Al-Naimat','Ali Olwan'],'Debutante absoluto; fue subcampeona de la Copa Asiática 2023.'),
 ('POR','Portugal','Portugal','pt','K','UEFA',6,9,0,'Tercer puesto (1966)',['Cristiano Ronaldo','Bruno Fernandes','Vitinha'],'Cristiano Ronaldo, a los 41 años, iguala el récord de Messi: sexto Mundial. Campeón de la Nations League 2025.'),
 ('COD','RD del Congo','Congo DR','cd','K','CAF',56,2,0,'Fase de grupos (1974, como Zaire)',['Cédric Bakambu','Yoane Wissa','Chancel Mbemba'],'Regresa 52 años después de su participación como Zaire; ganó el repechaje intercontinental.'),
 ('UZB','Uzbekistán','Uzbekistan','uz','K','AFC',50,1,0,'Debut',['Abdukodir Khusanov','Eldor Shomurodov','Otabek Shukurov'],'Debutante absoluto tras décadas rozando la clasificación.'),
 ('COL','Colombia','Colombia','co','K','CONMEBOL',13,7,0,'Cuartos de final (2014)',['James Rodríguez','Luis Díaz','Daniel Muñoz'],'La Tricolor vuelve tras perderse 2022. James, botín de oro en 2014, lidera; Lucho Díaz es la estrella.'),
 ('ENG','Inglaterra','England','gb-eng','L','UEFA',4,17,1,'Campeón (1966)',['Harry Kane','Jude Bellingham','Bukayo Saka'],'Clasificó con puntaje perfecto y sin recibir goles. Con Tuchel busca su segunda estrella, 60 años después.'),
 ('CRO','Croacia','Croatia','hr','L','UEFA',10,7,0,'Subcampeón (2018)',['Luka Modrić','Joško Gvardiol','Mateo Kovačić'],'Subcampeona 2018 y tercera en 2022. Modrić, a los 40 años, juega su quinto Mundial.'),
 ('GHA','Ghana','Ghana','gh','L','CAF',73,5,0,'Cuartos de final (2010)',['Mohammed Kudus','Antoine Semenyo','Jordan Ayew'],'Las Estrellas Negras rozaron las semifinales en 2010; vuelven tras la ausencia de 2022... presentes de nuevo.'),
 ('PAN','Panamá','Panama','pa','L','CONCACAF',30,2,0,'Fase de grupos (2018)',['Adalberto Carrasquilla','Michael Amir Murillo','José Fajardo'],'Segunda participación; ganó su grupo eliminatorio por encima de rivales históricos.'),
]
CONF_FULL = {'UEFA':'Europa','CONMEBOL':'Sudamérica','CONCACAF':'Norte y Centroamérica','CAF':'África','AFC':'Asia','OFC':'Oceanía'}
teams = []
for tid,es,espn,flag,grp,conf,rank,apps,titles,best,stars,note in T:
    teams.append({'id':tid,'name':es,'espn':espn,'flag':flag,'group':grp,'conf':conf,
        'confRegion':CONF_FULL[conf],'rank':rank,'apps':apps,'titles':titles,'best':best,
        'stars':stars,'note':note})
assert len(teams)==48, len(teams)
by_espn = {t['espn']:t['id'] for t in teams}

# ---------------------------------------------------------------- sedes
VENUES = {
 'Estadio Azteca':      {'city':'Ciudad de México','country':'México','cap':87523},
 'Estadio Akron':       {'city':'Guadalajara','country':'México','cap':49813},
 'Estadio BBVA':        {'city':'Monterrey','country':'México','cap':53500},
 'BMO Field':           {'city':'Toronto','country':'Canadá','cap':45736},
 'BC Place':            {'city':'Vancouver','country':'Canadá','cap':54500},
 'MetLife Stadium':     {'city':'Nueva York / Nueva Jersey','country':'EE. UU.','cap':82500},
 'Gillette Stadium':    {'city':'Boston (Foxborough)','country':'EE. UU.','cap':64628},
 'Lincoln Financial Field':{'city':'Filadelfia','country':'EE. UU.','cap':69796},
 'Hard Rock Stadium':   {'city':'Miami','country':'EE. UU.','cap':64767},
 'Mercedes-Benz Stadium':{'city':'Atlanta','country':'EE. UU.','cap':71000},
 'NRG Stadium':         {'city':'Houston','country':'EE. UU.','cap':72220},
 'AT&T Stadium':        {'city':'Dallas (Arlington)','country':'EE. UU.','cap':80000},
 'Arrowhead Stadium':   {'city':'Kansas City','country':'EE. UU.','cap':76416},
 'SoFi Stadium':        {'city':'Los Ángeles (Inglewood)','country':'EE. UU.','cap':70240},
 'Levi’s Stadium': {'city':'San Francisco (Santa Clara)','country':'EE. UU.','cap':68500},
 'Lumen Field':         {'city':'Seattle','country':'EE. UU.','cap':69000},
}

# ------------------------------------------------------- fase de grupos
# (numero, local, visitante, estadio)  fechas/horas vienen de ESPN
G = [
 (1,'MEX','RSA','Estadio Azteca'),(2,'KOR','CZE','Estadio Akron'),
 (25,'CZE','RSA','Mercedes-Benz Stadium'),(28,'MEX','KOR','Estadio Akron'),
 (53,'CZE','MEX','Estadio Azteca'),(54,'RSA','KOR','Estadio BBVA'),
 (3,'CAN','BIH','BMO Field'),(8,'QAT','SUI','Levi’s Stadium'),
 (26,'SUI','BIH','SoFi Stadium'),(27,'CAN','QAT','BC Place'),
 (51,'SUI','CAN','BC Place'),(52,'BIH','QAT','Lumen Field'),
 (5,'HAI','SCO','Gillette Stadium'),(7,'BRA','MAR','MetLife Stadium'),
 (29,'BRA','HAI','Lincoln Financial Field'),(30,'SCO','MAR','Gillette Stadium'),
 (49,'SCO','BRA','Hard Rock Stadium'),(50,'MAR','HAI','Mercedes-Benz Stadium'),
 (4,'USA','PAR','SoFi Stadium'),(6,'AUS','TUR','BC Place'),
 (31,'TUR','PAR','Levi’s Stadium'),(32,'USA','AUS','Lumen Field'),
 (59,'TUR','USA','SoFi Stadium'),(60,'PAR','AUS','Levi’s Stadium'),
 (9,'CIV','ECU','Lincoln Financial Field'),(10,'GER','CUW','NRG Stadium'),
 (33,'GER','CIV','BMO Field'),(34,'ECU','CUW','Arrowhead Stadium'),
 (55,'CUW','CIV','Lincoln Financial Field'),(56,'ECU','GER','MetLife Stadium'),
 (11,'NED','JPN','AT&T Stadium'),(12,'SWE','TUN','Estadio BBVA'),
 (35,'NED','SWE','NRG Stadium'),(36,'TUN','JPN','Estadio BBVA'),
 (57,'JPN','SWE','AT&T Stadium'),(58,'TUN','NED','Arrowhead Stadium'),
 (15,'IRN','NZL','SoFi Stadium'),(16,'BEL','EGY','Lumen Field'),
 (39,'BEL','IRN','SoFi Stadium'),(40,'NZL','EGY','BC Place'),
 (63,'EGY','IRN','Lumen Field'),(64,'NZL','BEL','BC Place'),
 (13,'KSA','URU','Hard Rock Stadium'),(14,'ESP','CPV','Mercedes-Benz Stadium'),
 (37,'URU','CPV','Hard Rock Stadium'),(38,'ESP','KSA','Mercedes-Benz Stadium'),
 (65,'CPV','KSA','NRG Stadium'),(66,'URU','ESP','Estadio Akron'),
 (17,'FRA','SEN','MetLife Stadium'),(18,'IRQ','NOR','Gillette Stadium'),
 (41,'NOR','SEN','MetLife Stadium'),(42,'FRA','IRQ','Lincoln Financial Field'),
 (61,'NOR','FRA','Gillette Stadium'),(62,'SEN','IRQ','BMO Field'),
 (19,'ARG','ALG','Arrowhead Stadium'),(20,'AUT','JOR','Levi’s Stadium'),
 (43,'ARG','AUT','AT&T Stadium'),(44,'JOR','ALG','Levi’s Stadium'),
 (69,'ALG','AUT','Arrowhead Stadium'),(70,'JOR','ARG','AT&T Stadium'),
 (23,'POR','COD','NRG Stadium'),(24,'UZB','COL','Estadio Azteca'),
 (47,'POR','UZB','NRG Stadium'),(48,'COL','COD','Estadio Akron'),
 (71,'COL','POR','Hard Rock Stadium'),(72,'COD','UZB','Mercedes-Benz Stadium'),
 (21,'GHA','PAN','BMO Field'),(22,'ENG','CRO','AT&T Stadium'),
 (45,'ENG','GHA','Gillette Stadium'),(46,'PAN','CRO','BMO Field'),
 (67,'PAN','ENG','MetLife Stadium'),(68,'CRO','GHA','Lincoln Financial Field'),
]
team_group = {t['id']:t['group'] for t in teams}

# ------------------------------------------------------- eliminatorias
# slots: W{g}=ganador grupo, R{g}=segundo grupo, T{groups}=mejor tercero, M{n}=ganador partido, L{n}=perdedor
K = [
 (73,'r32','RA','RB','SoFi Stadium'),
 (74,'r32','WE','TABCDF','Gillette Stadium'),
 (75,'r32','WF','RC','Estadio BBVA'),
 (76,'r32','WC','RF','NRG Stadium'),
 (77,'r32','WI','TCDFGH','MetLife Stadium'),
 (78,'r32','RE','RI','AT&T Stadium'),
 (79,'r32','WA','TCEFHI','Estadio Azteca'),
 (80,'r32','WL','TEHIJK','Mercedes-Benz Stadium'),
 (81,'r32','WD','TBEFIJ','Levi’s Stadium'),
 (82,'r32','WG','TAEHIJ','Lumen Field'),
 (83,'r32','RK','RL','BMO Field'),
 (84,'r32','WH','RJ','SoFi Stadium'),
 (85,'r32','WB','TEFGIJ','BC Place'),
 (86,'r32','WJ','RH','Hard Rock Stadium'),
 (87,'r32','WK','TDEIJL','Arrowhead Stadium'),
 (88,'r32','RD','RG','AT&T Stadium'),
 (89,'r16','M74','M77','Lincoln Financial Field'),
 (90,'r16','M73','M75','NRG Stadium'),
 (91,'r16','M76','M78','MetLife Stadium'),
 (92,'r16','M79','M80','Estadio Azteca'),
 (93,'r16','M83','M84','AT&T Stadium'),
 (94,'r16','M81','M82','Lumen Field'),
 (95,'r16','M86','M88','Mercedes-Benz Stadium'),
 (96,'r16','M85','M87','BC Place'),
 (97,'qf','M89','M90','Gillette Stadium'),
 (98,'qf','M93','M94','SoFi Stadium'),
 (99,'qf','M91','M92','Hard Rock Stadium'),
 (100,'qf','M95','M96','Arrowhead Stadium'),
 (101,'sf','M97','M98','AT&T Stadium'),
 (102,'sf','M99','M100','Mercedes-Benz Stadium'),
 (103,'third','L101','L102','Hard Rock Stadium'),
 (104,'final','M101','M102','MetLife Stadium'),
]

def norm(s):
    return unicodedata.normalize('NFKD', s or '').encode('ascii','ignore').decode().lower()

# ESPN: agrupar por par de equipos (fase de grupos) y por (fecha, estadio) para KO
espn_by_pair = {}
espn_rest = []
for e in ESPN:
    h, a = by_espn.get(e['home']), by_espn.get(e['away'])
    if h and a:
        espn_by_pair[frozenset((h,a))] = e
    else:
        espn_rest.append(e)

VENUE_ALIASES = {  # nombre ESPN (normalizado, por contains) -> nombre oficial usado aqui
 'azteca':'Estadio Azteca','banorte':'Estadio Azteca','ciudad de mexico':'Estadio Azteca',
 'akron':'Estadio Akron','guadalajara':'Estadio Akron',
 'bbva':'Estadio BBVA','monterrey':'Estadio BBVA',
 'bmo':'BMO Field','bc place':'BC Place','metlife':'MetLife Stadium',
 'gillette':'Gillette Stadium','lincoln':'Lincoln Financial Field',
 'hard rock':'Hard Rock Stadium','mercedes':'Mercedes-Benz Stadium',
 'nrg':'NRG Stadium','at&t':'AT&T Stadium','arrowhead':'Arrowhead Stadium',
 'sofi':'SoFi Stadium','levi':'Levi’s Stadium','lumen':'Lumen Field',
}
def venue_official(espn_name):
    n = norm(espn_name)
    for k,v in VENUE_ALIASES.items():
        if norm(k) in n: return v
    return None

matches = []
for no,h,a,venue in G:
    e = espn_by_pair.get(frozenset((h,a)))
    assert e, f'sin evento ESPN para {h}-{a}'
    # ESPN home/away puede estar invertido respecto a Wikipedia; conservar orden ESPN para marcadores
    eh = by_espn[e['home']]; ea = by_espn[e['away']]
    matches.append({'no':no,'stage':'group','group':team_group[h],
        'home':eh,'away':ea,'date':e['date'],'venue':venue,'espnId':e['id']})

# KO: emparejar por fecha+estadio
rest_by_key = {}
for e in espn_rest:
    v = venue_official(e['venue'] or '') or norm(e['city'] or '')
    rest_by_key.setdefault((e['date'][:10], v), []).append(e)

KO_DATES = {73:'2026-06-28',74:'2026-06-29',75:'2026-06-29',76:'2026-06-29',77:'2026-06-30',
 78:'2026-06-30',79:'2026-06-30',80:'2026-07-01',81:'2026-07-01',82:'2026-07-01',83:'2026-07-02',
 84:'2026-07-02',85:'2026-07-02',86:'2026-07-03',87:'2026-07-03',88:'2026-07-03',89:'2026-07-04',
 90:'2026-07-04',91:'2026-07-05',92:'2026-07-05',93:'2026-07-06',94:'2026-07-06',95:'2026-07-07',
 96:'2026-07-07',97:'2026-07-09',98:'2026-07-10',99:'2026-07-11',100:'2026-07-11',101:'2026-07-14',
 102:'2026-07-15',103:'2026-07-18',104:'2026-07-19'}

for no,stage,hs,as_,venue in K:
    cands = rest_by_key.get((KO_DATES[no], venue), [])
    # la fecha local puede cruzar a un dia mas en UTC
    if not cands:
        from datetime import date, timedelta
        d = date.fromisoformat(KO_DATES[no]) + timedelta(days=1)
        cands = rest_by_key.get((d.isoformat(), venue), [])
    assert len(cands)==1, f'partido {no}: {len(cands)} candidatos para {KO_DATES[no]} {venue}'
    e = cands[0]
    matches.append({'no':no,'stage':stage,'group':None,
        'home':hs,'away':as_,'date':e['date'],'venue':venue,'espnId':e['id']})

matches.sort(key=lambda m:(m['date'], m['no']))
assert len(matches)==104, len(matches)
assert len({m['espnId'] for m in matches})==104

os.makedirs(os.path.join(ROOT,'assets','data'), exist_ok=True)
json.dump({'teams':teams}, open(os.path.join(ROOT,'assets','data','teams.json'),'w'),
          ensure_ascii=False, indent=1)
json.dump({'venues':VENUES,'matches':matches},
          open(os.path.join(ROOT,'assets','data','matches.json'),'w'), ensure_ascii=False, indent=1)
print(f'OK: {len(teams)} equipos, {len(matches)} partidos')
