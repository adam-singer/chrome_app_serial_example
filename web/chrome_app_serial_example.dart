import 'dart:html';
import 'serial.dart';
import 'package:logging/logging.dart';
// JS: for (var i =0; i < 100; i++) chrome.serial.close(i, function (f) { console.log(f); });
void main() {
  Logger.root.level = Level.ALL; 
  Logger logger = new Logger("main");
  Logger.root.on.record.add((LogRecord r)=>print(r.message.toString()));
  
  SelectElement selectElement = query("#serialPorts");
  
  Serial.getPorts().then((result) { 
    logger.fine("getPorts = ${result}"); 
    logger.fine("getPorts = ${result.runtimeType}"); 
    result.forEach((port) {
      logger.fine("port = ${port} , ${port.runtimeType}"); 
      
      OptionElement optionElement = new OptionElement();
      optionElement.value = port;
      optionElement.text = port;
      selectElement.append(optionElement);
    });
  });
  
  Serial serial = new Serial();
  
  query("#openSerial")
  ..on.click.add((Event event) {
    serial.openPort(selectElement.value).then((result) { 
      serial.onRead = (String str) {
        ParagraphElement p = new ParagraphElement();
        p.text = str;
        DivElement container = query("#container");
        container.children.add(p);
        container.scrollTop = container.scrollHeight;
      };
      
      serial.startListening();
    });
  });
  
  query("#ping")
  ..on.click.add((Event event) {
    String data = query("#pingData").value;
    logger.fine("data ${data}");
    serial.write("${data}\n").then((result) {
      logger.fine("serial.write ${result.bytesWritten}");
    });
  });
}



