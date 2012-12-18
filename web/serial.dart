// Copyright (c) 2012, Adam Singer <financeCoding@gmail.com>.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library serial;

import 'dart:html';
import 'package:js/js.dart' as js;
import 'package:logging/logging.dart';

class OpenOptions {
  int bitrate;
  OpenOptions({this.bitrate: 9600});
}

class OpenInfo {
  int connectionId;
  OpenInfo(this.connectionId);
}

class ReadInfo {
  int bytesRead;
  var data;
  ReadInfo(this.bytesRead, this.data);
}

class WriteInfo {
  int bytesWritten;
  WriteInfo(this.bytesWritten);
}

class ControlSignalOptions {

  /**
   * Serial control signals that your machine can send. 
   * Missing fields will be set to false.
   */ 
  bool dtr;
  
  /**
   * Serial control signals that your machine can receive. 
   * If a get operation fails, success will be false, 
   * and these fields will be absent.
   * 
   * DCD (Data Carrier Detect) is equivalent to 
   * RLSD (Receive Line Signal Detect) on some platforms.
   */ 
  bool dcd;
  
  /**
   * Request to Send (RTS) signal is enabled during serial communication.
   * 
   * The Request to Transmit (RTS) signal is typically used in 
   * Request to Send/Clear to Send (RTS/CTS) hardware handshaking.
   */
  bool rts;
  
  /**
   * Clear-to-Send line.
   * 
   * The Clear-to-Send (CTS) line is used in Request to Send/Clear to 
   * Send (RTS/CTS) hardware handshaking. The CTS line is queried 
   * by a port before data is sent.
   */
  bool cts;
  ControlSignalOptions({this.dtr: false, this.dcd: false,
    this.rts: false, this.cts: false});
}

class Serial {
  OpenInfo openInfo;  
  Logger logger = new Logger("Serial");
  
  
  static Future<List<String>> getPorts() {
    Completer completer = new Completer();
    
    js.scoped(() {
      void callback(var result) {
        List list = new List();
        //print(result);
        for (int i = 0; i < result.length; i++) {
          list.add(result[i]);
        }
        
        completer.complete(list);
      };
      
      js.context.callback = new js.Callback.once(callback);
      var chrome = js.context.chrome;
      chrome.serial.getPorts(js.context.callback);
    });
    
    return completer.future;
  }
  
  Future<int> openPort(String serialPort) {
    Completer completer = new Completer();
    js.scoped(() {
      var chrome = js.context.chrome;
      void openInfoCallback(var openInfo) {
        logger.fine("openInfo = $openInfo");
        if (openInfo!=null)  {
          logger.fine("openInfo.connectionId = ${openInfo.connectionId}");
          this.openInfo = new OpenInfo(openInfo.connectionId);
          completer.complete(openInfo.connectionId);
        } else {
          // openInfo == null
          completer.completeException("openInfo == null");
        }
      };
      js.context.openInfoCallback = new js.Callback.once(openInfoCallback);
      
      var openOptions = js.map({
        'bitrate' : 9600
      });
      
      chrome.serial.open(serialPort, openOptions, js.context.openInfoCallback);
    });
    
    return completer.future;
  }
  
  Future<bool> close() {
    Completer completer = new Completer();
    
    if (openInfo != null) {
      js.scoped(() {
        var chrome = js.context.chrome;
        void closeCallback(var result) {
          logger.fine("closeCallback = ${result}");
          openInfo = null;
          bool b = result;
          completer.complete(b);
        };
        
        js.context.closeCallback = new js.Callback.once(closeCallback);
        chrome.serial.close(openInfo.connectionId, js.context.closeCallback);
      });
    } else {
      completer.completeException("openInfo is null");
    }
    
    return completer.future;
  }
  
  bool get isConnected => openInfo != null && openInfo.connectionId >= 0;
  
  Function onWrite;
  Future<WriteInfo> write(String data) {
    Completer completer = new Completer();
    
    if (isConnected) {
      js.scoped(() {
        var chrome = js.context.chrome;
        void writeCallback(var result) {   
          var writeInfo = new WriteInfo(result.bytesWritten);
          logger.fine("writeInfo ${writeInfo.bytesWritten}");
          
          if (onWrite != null) {
            onWrite(writeInfo);
          }
          
          completer.complete(writeInfo);
        };
        
        js.context.writeCallback = new js.Callback.once(writeCallback);
        
        var buf = new js.Proxy(js.context.ArrayBuffer, data.charCodes.length);
        var bufView = new js.Proxy(js.context.Uint8Array, buf)
        ..set(js.array(data.charCodes));
        
        chrome.serial.write(openInfo.connectionId, buf, js.context.writeCallback);
      });
    } else {
      completer.completeException("serial not connected");
    }

    return completer.future;
  }
  
  String dataRead = "";
  Function onRead;
  startListening() {
    if (isConnected) {
      dataRead = "";
      onCharRead();
    } else {
      // Not connected. 
    }
    dataRead = "";
  }
  
  // TODO: this should be the private method. 
  onCharRead() {
    if (isConnected) {
      js.scoped(() {
        var chrome = js.context.chrome;
        
        void _onCharRead(var readInfo) {
          var chrome = js.context.chrome;
          if (readInfo != null && readInfo.bytesRead > 0 && readInfo.data != null) {
            
            var bufView = new js.Proxy(js.context.Uint8Array, readInfo.data);
            
            List chars = [];
            for (var i = 0; i < bufView.length; i++) {
              chars.add(bufView[i]);
            }
            
            var str = new String.fromCharCodes(chars);
            if (str.endsWith("\n")) {
              // TODO: move to string buffer
              dataRead = "${dataRead}${str.substring(0, str.length - 1)}";
              if (onRead != null) {
                onRead(dataRead);
              }
              
              dataRead = "";
            } else {
              dataRead = "${dataRead}${str}";
            }
          }
          chrome.serial.read(openInfo.connectionId, 1, js.context._onCharRead);
        };
        
        js.context._onCharRead = new js.Callback.many(_onCharRead);
        
        chrome.serial.read(openInfo.connectionId, 1, js.context._onCharRead);
      });
    } else {
      return; // throw exception here?
    }
  }
}
