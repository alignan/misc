/*
 * Copyright (c) 2011-2014 ZOLERTIA LABS
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 *
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#include <stdio.h>
#include "Msp430Adc12.h"
#include "PrintfUART.h"

module SigFoxTMPDemoC {
  uses {
    interface Boot;
    interface Leds;

    interface UartStream as UartStreamOut;
    interface UartByte as UartByteOut;
    interface Resource as UartResourceOut;
    interface HplMsp430UsciA as UartConfigOut;

    interface Timer<TMilli> as ReadTimer;
    interface Timer<TMilli> as ReadRspBuffer;    
    interface Read<uint16_t> as TempSensor;
  }
}

/**
 * Simple test to periodically send a temperature reading from the
 * Z1 to SIGFOX backend.
 * @author Antonio Lignan <alinan@zolertia.com>
 */

// AT Commands always start with AT and finish with a CR>
// Responses start and end with <CR><LF>, except ATV0 and ATQ1 commands

implementation {

  #define BUFFER_SIZE 50

  bool boot = FALSE;  // Distinguish between serial config event

  norace uint8_t rspBytes = 0x00;
  norace uint8_t cmdBytes = 0x00;
  norace char RspBuffer[BUFFER_SIZE];
  norace char CmdBuffer[BUFFER_SIZE];

    msp430_uart_union_config_t config = { {
    ubr     :	UBR_8MHZ_9600,
    umctl   :	UMCTL_8MHZ_9600,
    ucmode  :	0,			// uart
    ucspb   :	0,			// one stop
    uc7bit  :	0,			// 8 bit
    ucpar   :	0,			// odd parity (but no parity)
    ucpen   :	0,			// parity disabled
    ucrxeie :	0,			// err int off
    ucssel  :	2,			// smclk
    utxe    :	1,			// enable tx
    urxe    :	1,			// enable rx
  } };

  void closeConn(){
    call UartResourceOut.release();
  }

  void cleanBuffers(){
    rspBytes = cmdBytes = 0;
    memset(RspBuffer, 0x00, BUFFER_SIZE);
    memset(CmdBuffer, 0x00, BUFFER_SIZE);

    // Reinitialize command buffer
    strncpy(CmdBuffer, (const char *)"AT$SS=", 6);
  }

  void printTitles(){
    printfUART("\n\n");
    printfUART("   ###############################\n");
    printfUART("   #        SIGFOX TEST          #\n");
    printfUART("   ###############################\n");
    printfUART("\n");
  }

  /**
   * This event is signalled when the MCU is done booting, 
   * user applications should start here
   */
  
  event void Boot.booted () {
    printfUART_init();
    printTitles();  
    cleanBuffers();    
    call UartResourceOut.request();
  }

  /**
   * After the serial resource is lock, we now have the bus control
   */
  
  event void UartResourceOut.granted(){
    call Leds.led2Toggle();

    // As the serial settings may be different from usci files, set ours
    call UartConfigOut.setModeUart(&config);
    call UartConfigOut.enableIntr();    
    
    // Check current version/device information
    call UartStreamOut.send((uint8_t*)"AT&V\n",5);

    // Send data every 5 min (300 seconds)
    call ReadTimer.startPeriodic(1024L*60*5);
  }

  event void ReadTimer.fired(void){
    call Leds.led1Toggle();
    #ifdef AT_TEST_MODE
      call UartStreamOut.send((uint8_t*)"AT\n",3);
      return;
    #endif

    // Poll temperature sensor
    call TempSensor.read();
  }

  /**
   * Stores received bytes and re-triggers a read-back timer, when
   * done receiving the timer will expire and show the received response
   */

  async event void UartStreamOut.receivedByte (uint8_t byte) { 
    RspBuffer[rspBytes++] = byte;
    call ReadRspBuffer.startOneShot(128L);
  }

  /**
   * Reads back the response given by the device, prints out to console
   */

  event void ReadRspBuffer.fired(void){
    uint8_t i;
    for (i=0; i<rspBytes; i++){
      printfUART("%c", RspBuffer[i]); 
    }
    printfUART("\n");

    // Clean afterwards
    cleanBuffers();
  }

  /**
   * Request a sample to the TMP102 built-in temperature sensor, readings
   * are in Celsius degrees.  You might want to compensate the values, as
   * the sensor heats +4-5ºC when Z1 is powered from USB
   */

  event void TempSensor.readDone(error_t error, uint16_t data){
    char aux[5];
    if (error == SUCCESS){
      call Leds.led2Toggle();
      if (data > 2047) data -= (1<<12);
      data *=0.625;
      printfUART("Temp: %2d.%1.2d (%u)\n", data/10, data>>2, data);

      // Clean before use
      cleanBuffers();

      // Format as hexadecimal with leading zero, copy to buffer
      // (SIGFOX expects 2-symbol hexadecimal values)
      snprintf(aux, 5, "%04x", data);
      strncpy(&CmdBuffer[6], aux, 4);

      // And append <CR>
      strncpy(&CmdBuffer[10], (const char*)"\n", 1);      
      call UartStreamOut.send((uint8_t*)(CmdBuffer),11);
    }
  }

  async event void UartStreamOut.receiveDone (uint8_t* buf, uint16_t len, error_t error) { }
  async event void UartStreamOut.sendDone (uint8_t* buf, uint16_t len, error_t error) { }
}