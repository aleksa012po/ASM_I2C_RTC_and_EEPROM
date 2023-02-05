;
; I2C_RTC_and_EEPROM.asm
;
; Created: 11.11.2022. 17:44:52
; Author : Aleksandar Bogdanovic
;

/* Arduino Asembler, I2C RTC i EEPROM. Rad sa oba ?ipa na jednom kontorleru. Osnove I2C adresiranja */

.dseg

.equ SCL		= 2				// SCL pin (Port B)
.equ SDA		= 3				// SDA pin (Port B)

.equ dir_bit	= 0				// Direction bit transfer u twi_adr

.equ read_bit	= 1				// Bit za TWI citanje
.equ write_bit	= 0				// Bit za TWI upisivanje

.equ half		= 22			// half - 1/2 period TWI delay (normal: 5.0us / fast: 1.3us)
.equ quar		= 11			// quar - 1/4 period TWI delay (normal: 2.5us / fast: 0.6us)

/* TWI = I2C */

.def twi_delay	= r16			// Delay loop promenljiva
.def twi_data	= r17			// TWI data transfer registar
.def twi_address= r18			// Adresni TWI registar
.def twi_bus	= r19			// TWI bus status registar

.def eeprom_high_b	= r20		// EEPROM high address byte
.def eeprom_low_b	= r21		// EEPROM low address byte
.def eeprom_byte	= r22		// Byte koji se cuva u EEPROM
.def counter		= r23		// Brojac - counter

.include "m328pdef.inc"

.cseg

rjmp main_program
///////////////////////////////////////
// Glavni program
///////////////////////////////////////
main_program:
	rcall	twi_init				// TWI inicijalizacija
	;---------------------------------
	rcall	write_rtc				// Postavlja vreme na RTC
	rcall	read_rtc				// Cita vreme sa RTC-a
	ldi		eeprom_high_b, 0x00
	ldi		eeprom_low_b,  0x00
	rcall	wr_string_eeprom
	ldi		counter, 10
	ldi		eeprom_high_b, 0x00
	ldi		eeprom_low_b,  0x00
loop:
	rcall	read_eeprom
	inc		eeprom_low_b
	dec		counter
	breq	end
	rjmp	loop
end:
	rjmp	end
/* Kraj programa koji je u loop-u */
///////////////////////////////////////

///////////////////////////////////////
// Normal ili Fast mode
///////////////////////////////////////
/* U ovom programu koristimo Normal mode (100KHz)
   Podesavanja:
   half - 1/2 period TWI delay (normal: 5.0us / fast: 1.3us)
   quar - 1/4 period TWI delay (normal: 2.5us / fast: 0.6us)

   Normal mode: half 22, quar 11 100KHz
   Fast mode: half 2, quar 1 */
///////////////////////////////////////
twi_half_d:
	ldi twi_delay, half
loop2:
	dec twi_delay
	brne loop2
	ret

twi_quar_d:
	ldi twi_delay, quar
loop1:
	dec twi_delay
	brne loop1
	ret
///////////////////////////////////////
// Inicijalizacija
///////////////////////////////////////
twi_init:
	clr twi_bus
	out PORTB, twi_bus
	out DDRB, twi_bus
	ret
///////////////////////////////////////
// TWI Repeat start
///////////////////////////////////////
twi_rep_start:
	sbi DDRB, SCL
	cbi DDRB, SDA
	rcall twi_half_d
	cbi DDRB, SCL
	rcall twi_quar_d
///////////////////////////////////////
// TWI start
///////////////////////////////////////
twi_start:
	mov twi_data, twi_address
	sbi DDRB, SDA
	rcall twi_quar_d
///////////////////////////////////////
// TWI Write
///////////////////////////////////////
twi_write:
	sec
	rol twi_data
	rjmp twi1_wr
twi1_bit:
	lsl twi_data
twi1_wr:
	breq twi_get_ack
	sbi DDRB, SCL
	brcc twi_low
	nop							
	cbi DDRB, SDA
	rjmp twi_high
twi_low:
	sbi DDRB, SDA
	rjmp twi_high
twi_high:
	rcall twi_half_d
	cbi DDRB, SCL
	rcall twi_half_d
	rjmp twi1_bit
///////////////////////////////////////
// Get acknowledge
///////////////////////////////////////
twi_get_ack:
	sbi DDRB, SCL
	cbi DDRB, SDA
	rcall twi_half_d
	cbi DDRB, SCL
wait:
	sbis PINB, SCL
	rjmp wait
	clc
	sbic PINB, SDA
	sec
	rcall twi_half_d
	ret
///////////////////////////////////////
// TWI transfer
///////////////////////////////////////
twi_transfer:
	sbrs twi_address, dir_bit
	rjmp twi_write
///////////////////////////////////////
// TWI read
///////////////////////////////////////
twi_read:
	rol twi_bus
	ldi twi_data, 0x01
twi_readb:
	sbi DDRB, SCL
	rcall twi_half_d
	cbi DDRB, SCL
	rcall twi_half_d
	clc
	sbis PINB, SDA
	sec
	rol twi_data
	brcc twi_readb
///////////////////////////////////////
// Put acknowledge
///////////////////////////////////////
twi_put_ack:
	sbi DDRB, SCL
	ror twi_bus
	brcc put_ack_l
	cbi DDRB, SDA
	rjmp put_ack_h
put_ack_l:
	sbi DDRB, SDA
put_ack_h:
	rcall twi_half_d
	cbi DDRB, SCL
twi_put_ackW:
	sbis PINB, SCL
	rjmp twi_put_ackW
	rcall twi_half_d
	ret
///////////////////////////////////////
// TWI stop
///////////////////////////////////////
twi_stop:
	sbi DDRB, SCL
	sbi DDRB, SDA
	rcall twi_half_d
	cbi DDRB, SCL
	rcall twi_half_d
	cbi DDRB, SDA
	rcall twi_half_d
	ret
////////////////////////////////////////
// EEPROM pisanje
///////////////////////////////////////
write_eeprom:
	ldi twi_address, 0xA0 + write_bit
	rcall twi_start

	mov twi_data, eeprom_high_b
	rcall twi_transfer

	mov twi_data, eeprom_low_b
	rcall twi_transfer

	mov twi_data, eeprom_byte
	rcall twi_transfer
	rcall twi_stop
	ret
////////////////////////////////////////
// EEPROM citanje
///////////////////////////////////////
read_eeprom:
	ldi twi_address, 0xA0 + write_bit
	rcall twi_start

	mov twi_data, eeprom_high_b
	rcall twi_transfer

	mov twi_data, eeprom_low_b
	rcall twi_transfer

	ldi twi_address, 0xA0 + read_bit
	rcall twi_rep_start

	sec
	rcall twi_transfer

	rcall twi_stop
	ret
///////////////////////////////////////
// RTC inicijalizacija
///////////////////////////////////////
write_rtc:
	// Godina (00 - 99)
	ldi twi_address, 0xD0 + write_bit
	rcall twi_start

	ldi twi_data, 0x06			// Year address
	rcall twi_transfer

	ldi twi_data, 0x22			// Upisuje godinu npr 22 je 2022. godina
	rcall twi_transfer
	rcall twi_stop
	;---------------------------------
	// Mesec (01 - 12)
	ldi twi_address, 0xD0 + write_bit
	rcall twi_start

	ldi twi_data, 0x05			// Month address
	rcall twi_transfer

	ldi twi_data, 0x11			// Upisuje mesec npr 05 - maj
	rcall twi_transfer
	rcall twi_stop
	;---------------------------------
	// Dan u mesecu (01. - 31.)
	ldi twi_address, 0xD0 + write_bit
	rcall twi_start

	ldi twi_data, 0x04			// Date address
	rcall twi_transfer

	ldi twi_data, 0x11			// Upisuje dan u mesecu, npr 16.
	rcall twi_transfer
	rcall twi_stop
	;---------------------------------
	// Dan u nedelji (01 - 07, 01 = nedelja)
	ldi twi_address, 0xD0 + write_bit
	rcall twi_start

	ldi twi_data, 0x03			// Day address
	rcall twi_transfer

	ldi twi_data, 0x06			// Upisuje dan u nedelji, 01 = nedelja, npr 05 = cetvrtak
	rcall twi_transfer
	rcall twi_stop
	;---------------------------------
	// Sat (01 - 12 AM/PM {12h clock}, 01 - 24 {24h clock} )
	ldi twi_address, 0xD0 + write_bit
	rcall twi_start

	ldi twi_data, 0x02			// Hour address
	rcall twi_transfer

	ldi twi_data, 0x21			// Upisuje 12 (AM/PM) / 24 sat
	rcall twi_transfer
	rcall twi_stop
	;---------------------------------
	// Minut (00 - 59)
	ldi twi_address, 0xD0 + write_bit
	rcall twi_start

	ldi twi_data, 0x01			// Minutes address
	rcall twi_transfer

	ldi twi_data, 0x31			// Upisuje minute
	rcall twi_transfer
	rcall twi_stop
	;---------------------------------
	// Sekunda (00 - 59)
	ldi twi_address, 0xD0 + write_bit
	rcall twi_start

	ldi twi_data, 0x00			// Seconds address
	rcall twi_transfer

	ldi twi_data, 0x10			// Upisuje sekunde
	rcall twi_transfer
	rcall twi_stop
	ret
// Kraj upisa

read_rtc:
	// Godina (00 - 99)
	ldi twi_address, 0xD0 + write_bit
	rcall twi_start

	ldi twi_data, 0x06			// Year address
	rcall twi_transfer

	ldi twi_address, 0xD0 + read_bit
	rcall twi_rep_start

	sec
	rcall twi_transfer
	rcall twi_stop
	;---------------------------------
	// Mesec (01 - 12)
	ldi twi_address, 0xD0 + write_bit
	rcall twi_start

	ldi twi_data, 0x05			// Month address
	rcall twi_transfer

	ldi twi_address, 0xD0 + read_bit
	rcall twi_rep_start

	sec
	rcall twi_transfer
	rcall twi_stop
	;---------------------------------
	// Dan u mesecu (01. - 31.)
	ldi twi_address, 0xD0 + write_bit
	rcall twi_start

	ldi twi_data, 0x04			// Date address
	rcall twi_transfer

	ldi twi_address, 0xD0 + read_bit
	rcall twi_rep_start

	sec
	rcall twi_transfer
	rcall twi_stop
	;---------------------------------
	// Dan u nedelji (01 - 07, 01 = nedelja)
	ldi twi_address, 0xD0 + write_bit
	rcall twi_start

	ldi twi_data, 0x03			// Day address
	rcall twi_transfer

	ldi twi_address, 0xD0 + read_bit
	rcall twi_rep_start

	sec
	rcall twi_transfer
	rcall twi_stop
	;---------------------------------
	// Sat (01 - 12 AM/PM {12h clock}, 01 - 24 {24h clock} )
	ldi twi_address, 0xD0 + write_bit
	rcall twi_start

	ldi twi_data, 0x02			// Hour address
	rcall twi_transfer

	ldi twi_address, 0xD0 + read_bit
	rcall twi_rep_start

	sec
	rcall twi_transfer
	rcall twi_stop
	;---------------------------------
	// Minut (00 - 59)
	ldi twi_address, 0xD0 + write_bit
	rcall twi_start

	ldi twi_data, 0x01			// Minutes address
	rcall twi_transfer

	ldi twi_address, 0xD0 + read_bit
	rcall twi_rep_start

	sec
	rcall twi_transfer
	rcall twi_stop
	;---------------------------------
	// Sekunda (00 - 59)
	ldi twi_address, 0xD0 + write_bit
	rcall twi_start

	ldi twi_data, 0x00			// Seconds address
	rcall twi_transfer

	ldi twi_address, 0xD0 + read_bit
	rcall twi_rep_start

	sec
	rcall twi_transfer
	rcall twi_stop
	ret
///////////////////////////////////////
// Write string to EEPROM
///////////////////////////////////////
wr_string_eeprom:
	ldi ZH,high(2*Data) 
	ldi ZL,low(2*Data)
add_string:
	lpm r24,Z+ 
	and r24,r24 					
	mov eeprom_byte, r24
	breq end_string
	rcall write_eeprom
;---------------------------------
; Delay 4ms at 16 MHz
    ldi  r25, 84
    ldi  r26, 29
L1: dec  r26
    brne L1
    dec  r25
    brne L1
;---------------------------------	
	inc eeprom_low_b
	rjmp add_string
	ret
// Kraj citanja

Data: .db "Aleksandar",0,0			// ASCII 0x41, 0x6C, 0x65, 0x6B, 0x73, 0x61, 0x6E, 0x64, 0x61, 0x72

end_string:
	ret
// Kraj citanja

	;		- Kraj programa -