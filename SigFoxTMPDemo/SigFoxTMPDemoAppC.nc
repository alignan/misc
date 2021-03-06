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


configuration SigFoxTMPDemoAppC { }

implementation {
  components MainC, LedsC, SigFoxTMPDemoC as App;

  // Application
  App.Boot -> MainC;
  App.Leds -> LedsC;

  // Serial to device
  components new Msp430Uart1C();
  App.UartStreamOut -> Msp430Uart1C;
  App.UartByteOut -> Msp430Uart1C;
  App.UartResourceOut -> Msp430Uart1C.Resource; 

  components HplMsp430UsciA1C as UartConfigOut;
  App.UartConfigOut -> UartConfigOut;

  // Timers
  components new TimerMilliC() as ReadTimer;
  App.ReadTimer -> ReadTimer;
  
  components new TimerMilliC() as ReadRspBuffer;
  App.ReadRspBuffer -> ReadRspBuffer;

  // Sensors
  components new SimpleTMP102C() as Temperature;
  App.TempSensor -> Temperature;  

}
