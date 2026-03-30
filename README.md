# SysON-MATLAB-Kopplung
MATLAB-Benutzeroberfläche und SysML-v2-Drohnenmodell zur API-basierten 
Kopplung zwischen SysON und MATLAB über die standardisierte SysML-v2-REST-API.

Entwickelt im Rahmen der Projektarbeit:
**„Methodischer Ansatz zur Kopplung heterogener Modelle zur Risikoanalyse 
im Kontext innovativer Luftmobilität im urbanen Raum"**  
HAW Hamburg | M.Sc. Flugzeugbau | 2026

---

## Inhalt

### MATLAB
| Datei | Beschreibung |
|-------|-------------|
| `SysON_SysMLv2_Analyse.m` | MATLAB-Skript der grafischen Benutzeroberfläche zur API-basierten Kopplung mit SysON |
| `SysON_SysMLv2_AnalyseApp.m` | MATLAB App-Version der Benutzeroberfläche |

### SysML v2 Drohnenmodell
| Datei | Beschreibung |
|-------|-------------|
| `HolistischeDrohne.sysml` | SysML-v2-Drohnenmodell im textuellen Format |
| `HolistischeDrohne.zip` | SysON-Projektexport – direkt über „Upload Project" in SysON importierbar |

---

## Verwendung

### SysML v2 Modell in SysON importieren
1. SysON starten (`http://localhost:8080`)
2. „Upload Project" auswählen
3. `HolistischeDrohne.zip` hochladen
4. Visibility aller Elemente auf `public` setzen

### MATLAB-Benutzeroberfläche starten
1. MATLAB öffnen
2. `SysON_SysMLv2_Analyse.m` oder `SysON_SysMLv2_AnalyseApp.m` ausführen
3. Server-Adresse eingeben (Standard: `http://localhost:8080/api/rest`)
4. Projekt- und Commit-ID des SysON-Projekts auswählen
5. Modelldaten abrufen und Anforderungsanalyse starten

---

## Voraussetzungen
- MATLAB R2025b oder neuer (ältere Versionen wurden nicht getestet)
- SysON lokal verfügbar (hier der Source-Code: https://github.com/eclipse-syson/syson)
- SysML v2 REST API (OMG Standard)

---

## Kontext
Das Drohnenmodell orientiert sich an den Subsystemen des MBSE-Plattformmodells 
nach Topal et al. (2025) aus der Holistic-UAM-Studie der TUHH [https://www.tuhh.de/acps/research/ongoing-research/holistische-studie-zur-it-sicherheit-von-uam-fahrzeugen].  
Die API-Kopplung basiert auf dem  ”SysML-v2-API-Cookbook“von SysON [https://doc.mbse-syson.org/syson/v2025.2.0/developer-guide/api-cookbook.html] sowie allgemein an den Beispielen des
”Systems-Modeling-GitHub-Repositories“ [https://github.com/Systems-Modeling/SysML-v2-API-Cookbook].
