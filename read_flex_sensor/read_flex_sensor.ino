// Connect the voltage-divider output to GPIO34.
const int FLEX_PIN = 34;

const float V_REF = 3.3;
const float R_FIXED = 50000.0;  // 50k ohm fixed resistor
const int ADC_MAX = 4095;      // ESP32 12-bit ADC

// Calibration values — adjust to your sensor.
const float R_FLAT = 105000.0;
const float R_BENT = 350000.0;

// Wiring assumed:
// 3.3V -> fixed resistor -> GPIO34 -> flex sensor -> GND

void setup() {
  Serial.begin(115200);
  pinMode(FLEX_PIN, INPUT);
  analogReadResolution(12);
}

void loop() {
  int adc_raw = analogRead(FLEX_PIN);
  float v_out = adc_raw * (V_REF / ADC_MAX);

  Serial.print("Time: ");
  Serial.print(millis());
  Serial.print(" ms | ADC: ");
  Serial.print(adc_raw);
  Serial.print(" | Voltage: ");
  Serial.print(v_out, 3);
  Serial.print(" V");

  if (adc_raw >= ADC_MAX) {
    Serial.println(" | Status: SATURATED_HIGH — check wiring");
  } else {
    float r_flex = R_FIXED * v_out / (V_REF - v_out);

    float angle =
        (r_flex - R_FLAT) * 90.0 / (R_BENT - R_FLAT);
    angle = constrain(angle, 0.0, 90.0);

    Serial.print(" | Resistance: ");
    Serial.print(r_flex, 0);
    Serial.print(" ohms | Angle: ");
    Serial.print(angle, 1);
    
    Serial.println(" degrees");
  }

  delay(250);
}