#include "HX711.h"

// Piny podłączone do HX711
#define DT_PIN  A2
#define SCK_PIN A3

HX711 waga;

// Kalibracja - wartość należy dostosować do swojego czujnika
float calibration_factor = -589.43; // Dla belki 5kg, do kalibracji
float measurement;

void setup() {
  Serial.begin(115200);
  Serial.println("Inicjalizacja HX711...");

  waga.begin(DT_PIN, SCK_PIN);
  waga.set_scale(calibration_factor); // ustawienie współczynnika kalibracji
  //waga.tare(20); // zerowanie wagi (tylko gdy na niej nic na początku nie ma) 

  Serial.println("Gotowe!");
  Serial.print("Odczyt: ");
  Serial.println(waga.get_units(10), 2); // odczyt w jednostkach wagi (gramy, jeśli dobrze skalibrowane)
  delay(500);
}

void loop() {
  unsigned long czas_ms = millis();  // czas od uruchomienia [ms]
  measurement = waga.get_units();  // uśrednianie z 10 próbek
  Serial.print(czas_ms);
  Serial.print(",");
  Serial.println(measurement, 2);

 // waga.power_down();
  //delay(100);
  //waga.power_up();
}
