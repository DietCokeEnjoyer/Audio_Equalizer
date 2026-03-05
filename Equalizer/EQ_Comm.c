/******************************************************************************/
/**
 *
 * @authors
 * Elias Dahl
 * Andres Reis
 *
 * @file EQ_Comm.c
 * 
 * This program initializes the hardware Audio equalizer by filling its coefficent
 * buffers and 0 initializing its sample buffers, then enabling it. Then, the 
 * program waits to recieve attenuation factor data from the LabView GUI program,
 * writes the data to the audio equalizer, and waits for the next attenuation 
 * factors. Modified from xuartlite_polled_example.c.

/***************************** Include Files *********************************/

#include "xparameters.h"
#include "xstatus.h"
#include "xuartlite.h"
#include "xil_printf.h"

#include "platform.h"
#include "xil_printf.h"

#include "coeffs.h"

/************************** Constant Definitions *****************************/

/*
 * The following constants map to the XPAR parameters created in the
 * xparameters.h file. They are defined here such that a user can easily
 * change all the needed parameters in one place.
 */
#ifndef SDT
#define UARTLITE_DEVICE_ID	XPAR_UARTLITE_0_DEVICE_ID
#else
#define XUARTLITE_BASEADDRESS	XPAR_XUARTLITE_0_BASEADDR
#endif

/* Addresses */
#define EQ_BASE_ADDR 0x10000
#define BUFFER_LOW_ADDR (EQ_BASE_ADDR + 0x34)
#define EQ_ENABLE_ADDR (EQ_BASE_ADDR + 0x3c)
#define ATTEN_FACTORS_LOW_ADDR (EQ_BASE_ADDR + 0x40)

/*
 * The following constant controls the length of the buffers to be sent
 * and received with the UartLite, this constant must be 16 bytes or less since
 * this is a single threaded non-interrupt driven example such that the
 * entire buffer will fit into the transmit and receive FIFOs of the UartLite.
 */
#define TEST_BUFFER_SIZE 13*2


/************************** Function Prototypes ******************************/
#ifndef SDT
int UartLitePolledExample(u16 DeviceId);
#else
int UartLitePolledExample(UINTPTR BaseAddress);
#endif

/************************** Variable Definitions *****************************/

XUartLite UartLite; /* Instance of the UartLite Device */

u8 RecvBuffer[TEST_BUFFER_SIZE]; /* Buffer for Receiving Data */

/*****************************************************************************/
/**
 *
 * Main function to call the Uartlite polled example.
 *
 *
 * @return	XST_SUCCESS if successful, otherwise XST_FAILURE.
 *
 * @note		None.
 *
 ******************************************************************************/

int main(void) {
	init_platform();

	volatile int *wrAddr;

	int Status;

	/* Fills coeffs and init buffers to 0s. */
	for (int band = 0; band < NUM_BANDS; ++band) {

		wrAddr = (int *) (EQ_BASE_ADDR + 4 * band);

		for (int tap = 0; tap < NUM_TAPS; ++tap) {

			if (band < 2) {
				wrAddr = (int *) (BUFFER_LOW_ADDR + 4 * band);
				*wrAddr = 0;
				wrAddr = (int *) (EQ_BASE_ADDR + 4 * band);
			}

			*wrAddr = coeffs[band][tap];
		}
	}

	/* Init attenuation factors to 1*/
	for (int band = 0; band < NUM_BANDS; ++band) {

		wrAddr = (int *) (ATTEN_FACTORS_LOW_ADDR + 4 * band);
		*wrAddr = 0x4000; // 1 in 2.14
	}

	// Enable EQ
	wrAddr = (int *) EQ_ENABLE_ADDR;
	*wrAddr = 1;

	/*
	 * Run the UartLite polled example, specify the Device ID that is
	 * generated in xparameters.h
	 */
#ifndef SDT
	Status = UartLitePolledExample(UARTLITE_DEVICE_ID);
#else
	Status = UartLitePolledExample(XUARTLITE_BASEADDRESS);
#endif
	if (Status != XST_SUCCESS) {
		xil_printf("Uartlite polled Example Failed\r\n");
		cleanup_platform();
		return XST_FAILURE;
	}

	xil_printf("Successfully ran Uartlite polled Example\r\n");
	cleanup_platform();
	return XST_SUCCESS;

}

/****************************************************************************/
/**
 * This function does a minimal test on the UartLite device and driver as a
 * design example. The purpose of this function is to illustrate
 * how to use the XUartLite component.
 *
 * This function sends data and expects to receive the data through the UartLite
 * such that a  physical loopback must be done with the transmit and receive
 * signals of the UartLite.
 *
 * This function polls the UartLite and does not require the use of interrupts.
 *
 * @param	DeviceId is the Device ID of the UartLite and is the
 *		XPAR_<uartlite_instance>_DEVICE_ID value from xparameters.h.
 *
 * @return	XST_SUCCESS if successful, XST_FAILURE if unsuccessful.
 *
 *
 * @note
 *
 * This function calls the UartLite driver functions in a blocking mode such that
 * if the transmit data does not loopback to the receive, this function may
 * not return.
 *
 ****************************************************************************/
#ifndef SDT
int UartLitePolledExample(u16 DeviceId)
#else
int UartLitePolledExample(UINTPTR BaseAddress)
#endif
{
	int Status;
	unsigned int ReceivedCount = 0;
	int Index;

	/*
	 * Initialize the UartLite driver so that it is ready to use.
	 */
#ifndef	SDT
	Status = XUartLite_Initialize(&UartLite, DeviceId);
#else
	Status = XUartLite_Initialize(&UartLite, BaseAddress);
#endif
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	/*
	 * Perform a self-test to ensure that the hardware was built correctly.
	 */
	Status = XUartLite_SelfTest(&UartLite);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	/*
	 * Initialize the receive buffer bytes to zero.
	 */
	for (Index = 0; Index < TEST_BUFFER_SIZE; Index++) {
		RecvBuffer[Index] = 0;
	}

	/*
	 * Receive the number of bytes which is transferred.
	 * Data may be received in fifo with some delay hence we continuously
	 * check the receive fifo for valid data and update the receive buffer
	 * accordingly.
	 */
	volatile int *wrAddr;
	while (1) {
		ReceivedCount = 0;
		/* Wait for new attenuation factors to be sent*/
		while (1) {
			ReceivedCount += XUartLite_Recv(&UartLite,
					RecvBuffer + ReceivedCount,
					TEST_BUFFER_SIZE - ReceivedCount);
			if (ReceivedCount == TEST_BUFFER_SIZE) {
				break;
			}
		}

		/*Write the new attenuation factors*/
		for (int band = 0; band < NUM_BANDS; ++band) {

			wrAddr = (int *) (ATTEN_FACTORS_LOW_ADDR + 4 * band);
			int highByte = RecvBuffer[band * 2] << 8;
			int lowByte = RecvBuffer[(band * 2) + 1];
			*wrAddr = lowByte | highByte;
		}

	}

	return XST_SUCCESS;
}
