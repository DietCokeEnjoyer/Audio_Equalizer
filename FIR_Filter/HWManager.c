#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "impulse.h"
#include "sin_input_1.h"
#include "sin_input_2.h"

#define BASE_ADDR 0x10000
#define BUFFER_ADDR (BASE_ADDR + 0x4)
#define RESULT_ADDR  (BASE_ADDR + 0x8)
#define MAC_STATUS_ADDR (BASE_ADDR + 0xC)

volatile int *COEFF_PTR = (int *) BASE_ADDR;
volatile int *BUFFER_PTR = (int *) BUFFER_ADDR;
volatile int *RESULT_PTR = (int *) RESULT_ADDR;
volatile int *MAC_STATUS_PTR = (int *) MAC_STATUS_ADDR;
int macStatus;
int results[ARRAY_SIZE];
int main() {
	init_platform();

	// Fill Coeff Ram
	for (int i = 0; i < NUM_TAPS; ++i) {
		*COEFF_PTR = filterCoeffs[i];
	}
	// Write Samples to Buffer
	for (int i = 0; i < ARRAY_SIZE; ++i) {
		*BUFFER_PTR = sine_2[i];
		do {
			macStatus = *MAC_STATUS_PTR;
		} while (macStatus == 1);
		results[i] = *RESULT_PTR;
	}

	for (int i = 0; i < ARRAY_SIZE; ++i) {
		xil_printf("%d\n", results[i]);
	}

	cleanup_platform();
	return 0;
}
