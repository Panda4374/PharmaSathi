#include "SPIFFS.h"

void setup() {
  Serial.begin(115200);
  
  // Mount SPIFFS before formatting
  if (!SPIFFS.begin(false)) { // Use false to not format on mount failure (optional)
    Serial.println("Failed to mount SPIFFS");
    return;
  }

  Serial.println("\nFormatting SPIFFS...");
  if (SPIFFS.format()) {
    Serial.println("SPIFFS successfully formatted (all files deleted)");
  } else {
    Serial.println("Error formatting SPIFFS");
  }
  
  // Verify by listing files
  Serial.println("\nListing files after format:");
  File root = SPIFFS.open("/");
  File file = root.openNextFile();
  while(file){
    Serial.print("FILE: ");
    Serial.println(file.name());
    file.close(); // Close the file object before opening the next
    file = root.openNextFile();
  }
  if (!file) {
    Serial.println("No files found. The file system is empty.");
  }
  root.close();
}

void loop() {
  // Nothing to do in loop
}
