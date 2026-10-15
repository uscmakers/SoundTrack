// Pin Definitions
const int FLEX_PIN = A0; // Use GPIO34 for ESP32

// Circuit Constants
const float V_REF = 3.3;       
const float R_FIXED = 50000.0; // 5k Ohm fixed resistor
const int ADC_MAX = 4095;      // 10-bit for Uno, 4095 for ESP32 (12-bit)

// Calibration Constants (Measure these with your multiFelmeter!)
const float R_FLAT = 105000.0;  // Resistance at 0 degrees
const float R_BENT = 350000.0;  // Resistance at 90 degrees

void setup() {
  Serial.begin(115200);
  pinMode(FLEX_PIN, INPUT);
  analogReadResolution(12); // Standardize to 10-bit if using ESP32
}

void loop() {
  int adc_raw = analogRead(FLEX_PIN);
  
  // Step 1: ADC to Voltage
  float v_out = adc_raw * (V_REF / ADC_MAX);
  
  // Prevent division by zero if sensor is disconnected
  if (v_out >= V_REF) v_out = V_REF - 0.01; 
  
  // Step 2: Voltage to Resistance
  float r_flex = R_FIXED * (v_out / (V_REF - v_out));
  
  // Step 3: Resistance to Angle
  float angle = (r_flex - R_FLAT) * (90.0 / (R_BENT - R_FLAT));
  
  // Constrain angle to physical limits
  angle = constrain(angle, 0.0, 90.0);
  
  Serial.print("Output voltage");
  Serial.print(v_out);
  Serial.print("Resistance: ");
  Serial.print(r_flex);
  Serial.print(" ohms | Angle: ");
  Serial.println(angle);
  
  delay(50);
}
