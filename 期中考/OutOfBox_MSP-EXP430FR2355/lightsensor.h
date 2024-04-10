#ifndef LIGHTSENSOR_H_
#define LIGHTSENSOR_H_

#define LIGHTSENSOR_MODE 0

#define TIMER_PERIOD 650
#define DUTY_CYCLE  325


extern int calibratedADC;
extern int deadzone;
extern int runningAvg;


// Appliation mode
extern char mode;

/* FRAM Variable that stores lightsensor ADC results*/
extern unsigned int lightsensor_ADC_Result;          // ADC conversion result

void lightsensor_init_SACOA(void);
void lightsensor_init_ADC(void);


#endif /* LIGHTSENSOR_H_ */
