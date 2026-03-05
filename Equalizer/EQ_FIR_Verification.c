/******************************************************************************
* Copyright (C) 2023 Advanced Micro Devices, Inc. All Rights Reserved.
* SPDX-License-Identifier: MIT
******************************************************************************/
/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"

#include "coeffs.h"
#include "sines.h"

short buffer[NUM_TAPS];
short output[NUM_SAMPLES];
int bufferIndex;

void InitFilter(){
	for(int i = 0;i < NUM_TAPS;++i){
		buffer[i] = 0;
	}
	bufferIndex = 0;
}

short Filter(int band){
	int sum = 0;
	int tap_index = bufferIndex ;

	for(int k = 0; k < NUM_TAPS; k++){
		 sum += coeffs[band][k]*buffer[tap_index];
		 tap_index-- ;
		 if (tap_index < 0){
			 tap_index = NUM_TAPS-1 ;
		 }
	}
	sum += 0x4000; // 1/2 of LSB.
	short roundedSum = sum >> 15;
	return roundedSum;
}

int main()
{
    init_platform();
    xil_printf("START!") ;

    for(int band = 0; band < NUM_BANDS; ++band){
    	InitFilter();
    	for (int n = 0; n < NUM_SAMPLES; ++n){
        	buffer[bufferIndex] = sine_1318[n];
        	output[n] += Filter(band);
        	bufferIndex++;
        	if(bufferIndex > NUM_TAPS-1){
        		bufferIndex = 0;
        	}
    	}
    }


    for(int i = 0; i < NUM_SAMPLES; i++){
    	xil_printf("%d\n", output[i]) ;
	}
    cleanup_platform();
    return 0;
}
