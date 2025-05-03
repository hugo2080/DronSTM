#include "HX711.h"

// Piny podłączone do HX711
#define DT_PIN  A2
#define SCK_PIN A3

HX711 waga;
float ciezar;

// Kalibracja - wartość należy dostosować do swojego czujnika
float calibration_factor = -183.655; // Dla belki 5kg, do kalibracji

void setup() {
  Serial.begin(115200);
  Serial.println("Inicjalizacja HX711...");

  waga.begin(DT_PIN, SCK_PIN);
  waga.set_scale();
  waga.tare(); // zerowanie wagi

  Serial.println("Gotowe!");
}

void loop() {
  if (Serial.available()) {
    char command = Serial.read();

    if (command == 'p') {
      Serial.println("Wykonuję pomiar...");
      float reading = waga.get_units(10);
      Serial.print("Result: ");
      Serial.println(reading);
    }
  }
}
