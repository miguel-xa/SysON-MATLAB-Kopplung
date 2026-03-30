package HolistischeDrohne {
	private import HolistischeDrohne::*;
	view 'Gesamtübersicht' : StandardViewDefinitions::GeneralView {
		expose HolistischeDrohne;
		expose HolistischeDrohne::'drohne : HolistischeDrohne';
		expose HolistischeDrohne::Batteriesystem;
		expose HolistischeDrohne::Antriebsystem;
		expose HolistischeDrohne::KommunikationsSubsystem;
		expose ;
		expose HolistischeDrohne::'drohne : HolistischeDrohne'::batterie;
		expose HolistischeDrohne::'drohne : HolistischeDrohne'::sensorik;
		expose HolistischeDrohne::SensorSubsystem;
		expose HolistischeDrohne::'drohne : HolistischeDrohne'::antrieb;
		expose HolistischeDrohne::'drohne : HolistischeDrohne'::kommunikation;
		expose HolistischeDrohne::'drohne : HolistischeDrohne'::Navigation;
		expose ;
		expose ;
		expose HolistischeDrohne::Drohnenspezifikation::Massenanforderung;
		expose HolistischeDrohne::Drohnenspezifikation::drohne;
		expose ;
		expose HolistischeDrohne::NavigationsSubsystem;
		expose ;
		expose HolistischeDrohne::Drohnenspezifikation::Massenanforderung::'gesamtMasse <= maximalMasse';
		expose HolistischeDrohne::HolistischeDrohne;
		expose HolistischeDrohne::'maximalMasse >= aktuelleMasse';
		expose HolistischeDrohne::Rahmen;
		expose HolistischeDrohne::'drohne : HolistischeDrohne'::rahmen;
		expose HolistischeDrohne::HolistischeDrohne;
		expose HolistischeDrohne::Drohnenspezifikation;
		expose HolistischeDrohne::'drohne : HolistischeDrohne'::gesamtMasse;
		expose HolistischeDrohne::'drohne : HolistischeDrohne'::sensorik::senMasse;
		expose HolistischeDrohne::KommunikationsSubsystem::komMasse;
		expose HolistischeDrohne::Antriebsystem::antMasse;
		expose HolistischeDrohne::Rahmen::ramMasse;
		expose HolistischeDrohne::Batteriesystem::batMasse;
		expose HolistischeDrohne::NavigationsSubsystem::navMasse;
		expose HolistischeDrohne::'drohne : HolistischeDrohne'::Navigation::navMasse;
		expose HolistischeDrohne::SensorSubsystem::senMasse;
		expose HolistischeDrohne::'drohne : HolistischeDrohne'::kommunikation::komMasse;
		expose HolistischeDrohne::'drohne : HolistischeDrohne'::antrieb::antMasse;
		expose HolistischeDrohne::'drohne : HolistischeDrohne'::rahmen::ramMasse;
		expose HolistischeDrohne::'drohne : HolistischeDrohne'::batterie::batMasse;
		expose HolistischeDrohne::Drohnenspezifikation::Massenanforderung::'gesamtMasse > 0 [kg]';
		expose HolistischeDrohne::Drohnenspezifikation::Massenanforderung::maximalMasse;
		expose HolistischeDrohne::Drohnenspezifikation::Batterieanforderung;
		expose HolistischeDrohne::Drohnenspezifikation::Batterieanforderung::minimalKapazitaet;
		expose HolistischeDrohne::Drohnenspezifikation::Batterieanforderung::batterieKapazitaet;
		expose HolistischeDrohne::Drohnenspezifikation::Batterieanforderung::minimalKapazitaet;
		expose HolistischeDrohne::Drohnenspezifikation::Batterieanforderung::'batterieKapazitaet > 0 [J]';
		expose HolistischeDrohne::Drohnenspezifikation::Batterieanforderung::'batterieKapazitaet >= minimalKapazitaet';
		expose HolistischeDrohne::Batteriesystem::batterieKapazitaet;
		expose HolistischeDrohne::'drohne : HolistischeDrohne'::batterie::batterieKapazitaet;
	}
	package HolistischeDrohne {
		private import ISQThermodynamics::*;
		private import NavigationsSubsystem::*;
		private import ISQBase::*;
		part 'drohne : HolistischeDrohne' : HolistischeDrohne::HolistischeDrohne {
			doc /*  */
			part batterie : Batteriesystem {
				attribute batMasse = 1.2 [SI::kilogram];
				attribute batterieKapazitaet = 400000 [SI::joule];
			}
			part sensorik : SensorSubsystem {
				attribute senMasse = 0.3 [SI::kilogram];
			}
			part antrieb : Antriebsystem {
				attribute antMasse = 0.8 [SI::kilogram];
			}
			part kommunikation : KommunikationsSubsystem {
				attribute komMasse = 0.2 [SI::kilogram];
			}
			part Navigation : NavigationsSubsystem {
				attribute navMasse = 0.1 [SI::kilogram];
			}
			part rahmen : Rahmen, HolistischeDrohne::Rahmen {
				attribute ramMasse = 0.9 [SI::kilogram];
			}
			attribute gesamtMasse = 3.5 [SI::kilogram];
		}
		part def Batteriesystem {
			doc /* Batteriesystem bestehend aus LiPo-Akkus (Lithium-Polymer) zur Energieversorgung */
			attribute batMasse :> mass;
			attribute batterieKapazitaet :> energy;
		}
		part def Antriebsystem {
			doc /* Antriebssystem bestehend aus Elektromotoren und Propeller */
			attribute antMasse :> mass;
		}
		part def KommunikationsSubsystem {
			doc /* Subsystem für drahtlose bidirektionale Funkverbindung zwischen Fernsteuerung (Sender) und Drohne (Empfänger) */
			attribute komMasse :> mass;
		}
		part def SensorSubsystem {
			doc /* Sensorsubsystem für Situationserkennung und Kollisionsvermeidung */
			attribute senMasse :> mass;
		}
		requirement Drohnenspezifikation {
			doc /* Die Drohnenspezifiaktion enthält die funktionalen Anforderungen der holistischen Drohne */
			requirement <REQ1> Massenanforderung {
				doc /* Die Drohne darf ein Abfluggewicht von 4 kg nicht überschreiten, gemäß EU-Drohnenverordnung Klasse C2 */
				attribute maximalMasse :> mass;
				attribute gesamtMasse :> mass;
				constraint 'gesamtMasse <= maximalMasse' {
					gesamtMasse <= maximalMasse
				}
				constraint 'gesamtMasse > 0 [kg]' {
					gesamtMasse > 0 [SI::kilogram]
				}
				attribute maximalMasse = 4 [SI::kilogram];
			}
			subject drohne :> HolistischeDrohne;
			requirement <REQ2> Batterieanforderung {
				doc /* Die Drohne muss eine Batterie besitzen, deren Kapazität ausreichend ist, um den Betrieb der Drohne zu ermöglichen. */
				attribute minimalKapazitaet :> energy;
				attribute batterieKapazitaet :> energy;
				attribute minimalKapazitaet = 432000 [SI::joule];
				constraint 'batterieKapazitaet > 0 [J]' {
					batterieKapazitaet > 0 [SI::joule]
				}
				constraint 'batterieKapazitaet >= minimalKapazitaet' {
					batterieKapazitaet >= minimalKapazitaet
				}
			}
		}
		HolistischeDrohne;
		part def NavigationsSubsystem {
			doc /* Subsystem für Navigation und kooperative Lokalisierung */
			attribute navMasse :> mass;
		}
		constraint 'maximalMasse >= aktuelleMasse';
		part def Rahmen;
		part def Rahmen {
			doc /* Strukturelles Traggerüst der Drohne hergestelt aus Kohlenstofffaserverbundwerkstoffen */
			attribute ramMasse :> mass;
		}
		part def HolistischeDrohne {
			doc /* UAM-Drohne nach Topal et a. (2025) */
			attribute gesamtMasse :> mass;
		}
		attribute ISQBase;
	}
}