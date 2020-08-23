	.org	000h
	.include "1802.inc"               ; Include the R0-R15 definitions
RAM  = 0800h                              ; System/Data memory page
RAMStack = RAM+BFh                        ; Initial stack value

Reset:
	        ghi r0               ; Clear accumulator (D=0 on reset)
	        phi r1               ; R1.High = Interrupt
	        ldi RAM / 256        ; D = System Memory Page
	        phi r2               ; R2.High = Stack Base
	        ldi VideoInt & 255   ; R1.Low = Interrupt Routine
	        plo r1               ; 
	        ldi RAMStack & 255   ; R2.Low = Stack Base
	        plo r2               ; 
		ldi start / 256      ; R3.High = main
	        phi r3               ; 
	        ldi start & 255      ; R3.Low = main
	        phi r3               ; 
		sep r3       ; Go to start
_return:
		ldxa
		ret
VideoInt:
		dec r2
		sav
		dec r2
		str r2
		nop
		nop
		nop
		ldi 00
		phi r0
		ldi 00
		plo r0
_loop:		glo r0
		sex r2
		sex r2
		dec r0
		plo r0
		sex r2
		dec r0
		plo r0
		sex r2
		dec r0
		plo r0
		bn1 _loop
		br _return
			

MAX_SEGMENT_Y = 27	;up to 31
MAX_SPEED = 23 ;230
TIMER_START_LO = 0
TIMER_START_HI = 9
START_PERSPECTIVE_Y = 17
LIGHT_POSITION_Y = 101 ;lower byte
WHEEL_LIMIT = 8 ;-8..8
WHEEL_LIMIT_SPEEDUP = 4
CAR_X_LIMIT = 63 ;-63..63
SPEED_SKID_START = 7
ROAD_LIMIT = 55	;-55..55
MAX_SPEED_ROADSIDE = 11	;(110)
DEC_SPEED_ROADSIDE = 4


rDataPointer = 2
r3Buf = 3
r4buf = 4
r5Buf = 5

rLoTimer = 6
rHiCounter = 6
rScreenYAdr = 7
rHiCarX = 8
rLoWheel = 8
rLoDxCorr = 9
rHiDeltaX = 9
rRoadSectorAdr = 10
rMarksWidthY = 11
rHiSpeed = 12
rloSpeedCounter = 12
rGlobalState = 15

mRoadSize = 51
mRoadStartAdr = 52
mPerspectiveY = 53
;54-56 used
mData = 57

mSpeedHi = 58
mSpeedLo = 60
mSpeedSpace = 61
mTimerHiSpace = 62
mTimerHi = 63
mTimerLow = 64
mTimerLowSpace = 65
mScoreSpace = 66
mScoreHi = 67
mScoreLow = 71

mBtmDigits = RAM+88
mBtmHorizonStart = RAM+128
mBtmHorizonEnd = RAM+255

	.org 100h
start:
		sex r2
		dec r2 
		inp 1		; turns video on
		inc r2
		;disable interrupt and set X = 2, P = 3
		sex r3
		dis
		.db  $23
		
		req ;sound off

		ldi >RAM
		phi rDataPointer
		phi rScreenYAdr

clearRam:
		ldi <(RAM+255)
clearRamLoop:
		plo rDataPointer		;with faster loop real Studio not starting
		ldi 0
		stxd
		glo rDataPointer
		bnz clearRamLoop

		phi rLoTimer		; = 0


		ldi >marksWidthY
		phi rMarksWidthY
		ldi <marksWidthY
		plo rMarksWidthY

		ldi >roadData1
		phi rRoadSectorAdr
		ldi <roadData1
		plo rRoadSectorAdr

		ldi 1
		plo rGlobalState

		ldi <menuWaitVsync
		plo r1
		ldi >menuWaitVsync
		phi r1
		sep r1


scanAccelKey:
		sex r1
		out 2
		.db 5
		ldi 0
		bn4 notBreak
		ghi rHiSpeed
		shr
		shr
notBreak:
		adi 1
		plo r4buf

		sex r1
		out 2
		.db 2
		ldi mSpeedHi
		plo rDataPointer
		sex rDataPointer

		;conver speed 0-200 to 0-20 to save in rSpeed hi
		ldn rDataPointer
		shl 					;mul 10
		shl
		shl
		add
		add
		inc rDataPointer
		add
		phi rHiSpeed
		inc rDataPointer

		smi MAX_SPEED_ROADSIDE
		bnf noNeedDecSpeed
		; if speed more MAX_SPEED_ROADSIDE
		ghi rHiCarX
		adi ROAD_LIMIT
		adi 255-ROAD_LIMIT*2
		bnf checkTurn			;and check car X pos, if on roadside then dec dpeed
		ldi DEC_SPEED_ROADSIDE
		br decSpeedNext
checkTurn:
		ldn rDataPointer
		shr 
		bdf noNeedDecSpeed		;only odd speed for speed flicker
		glo rLoWheel
		adi WHEEL_LIMIT_SPEEDUP
		adi 255-WHEEL_LIMIT_SPEEDUP*2
		bdf decSpeed 			;check turn adder more half and not inc speed if true

noNeedDecSpeed:
		b4 incSpeed

decSpeed:
		ghi rHiSpeed
		add		
		bz changeSpeedEnd

		glo r4buf
decSpeedNext:
		sd 				;b for -2 for low byte
		str rDataPointer
		bdf changeSpeedEnd
		adi 10
		stxd
		ldi 1
		br decSpeedNext

incSpeed:
		ghi rHiSpeed
		smi MAX_SPEED
		bdf changeSpeedEnd
		ldi 1
		skp
incSpeedLoop:
		stxd
		adc
		str rDataPointer
		smi 10
		bdf incSpeedLoop
changeSpeedEnd:

updateTimerBtm:
		glo rLoTimer
		ani 0xC0
		bz updateTimerBtmEnd
		glo rLoTimer
		ani 0x0F
		plo rLoTimer
		ldi mTimerLow	
		plo rDataPointer
		ldn rDataPointer
		bnz updateTimerBtmDec
		ldi 9
		stxd
		ldn rDataPointer
		bnz updateTimerBtmDec
		ldi 255
		plo rGlobalState	;game over
		inc rDataPointer
		inc rDataPointer
		ldi <chrR
		stxd
		ldi <chrE
		stxd
		ldi <chrV
		stxd
		ldi 1				;after -1 is chr0
updateTimerBtmDec:
		smi 1
		stxd
updateTimerBtmEnd:

drawSpeedAndTimer:
		ldi <mSpeedHi
		plo rDataPointer
		ldi <digitsPos
		plo r3Buf


drawString:
;508; 43
		ldi >chr0
		phi r5Buf
		phi r4buf
		phi r3Buf
		sex rScreenYAdr

		lda r3Buf
drawStringMainLoop:
		plo rScreenYAdr
		lda rDataPointer
		plo r5Buf
		ldn r5Buf
		plo r5Buf
		lda rDataPointer
		plo r4buf
		ldn r4buf
		plo r4buf					

drawTwoCharsLoop:
		lda r5Buf
		ani $F0
		str rScreenYAdr
		lda r4buf
		ani $0F
		or
		str rScreenYAdr
		glo rScreenYAdr
		adi 8
		plo rScreenYAdr
		smi <mBtmDigits+8*5
		bnf drawTwoCharsLoop
		
		lda r3Buf				;next scr adr
		bnz drawStringMainLoop

		lbr waitVsync


		.org $200-7
drawRoad:

r14h_PixelData = r3Buf
r15h_PixelData = r4buf
rRowAdr = r5Buf

		ldi >pixelData
		phi r14h_PixelData
		phi r15h_PixelData
		ldi >(RAM+256)
		phi rRowAdr

clearRoad:
		sex rRowAdr
clearRoadSkipZeroLoop:
		lda rMarksWidthY
		bz clearRoadSkipZeroLoop
clearRoadLoop:
		lda rMarksWidthY
		plo rRowAdr
		ldi 0
		stxd
		stxd
		stxd
		stxd
		stxd
		stxd
		stxd
		str rRowAdr
		lda rMarksWidthY
		bz clearRoadSkipZeroLoop
		ani 1
		bz clearRoadLoop

		plo rScreenYAdr				;rScreenYAdr = 0
		
		ghi rHiSpeed
		bz drawPrevious			;just redraw when speed = 0
		inc rMarksWidthY
drawPrevious:
		ldn rMarksWidthY
		plo rMarksWidthY

updateDeltaXAndDxCorr:
		sex rDataPointer
		ldi <mData
		plo rDataPointer
		ldi 128
		str rDataPointer 		; lineError = 128
		ghi rHiCarX
		shl
		shl
		bnf drawI

drawD:
		xri 11111100b
		adi 00000100b
		phi rHiDeltaX
		ldi 35
		plo rLoDxCorr
drawLoopD:
		inc rScreenYAdr
		ghi rHiDeltaX
		add
		str rDataPointer				; set error; X to xCorr
		bdf drawIfMarkD
		inc rLoDxCorr
drawIfMarkD:
		lda rMarksWidthY
		bz drawLoopD		

		glo rLoDxCorr
		shl
        sex rScreenYAdr
        add
		plo r15h_PixelData
		dec rMarksWidthY
		sex rMarksWidthY
		sm
		plo r14h_PixelData
		inc rMarksWidthY
		;calc screen offset for left road border
		lda r14h_PixelData
		sd
		plo rRowAdr
		ldn r14h_PixelData
		str rRowAdr				;put pixel
		;calc screen offset for right road border
		lda r15h_PixelData
		sd
		plo rRowAdr
		ldn r15h_PixelData
		str rRowAdr 			;put pixel

		lda rMarksWidthY
		add
		sex rDataPointer
		bnz drawLoopD
		br drawRoadEnd

drawI:
		phi rHiDeltaX
		ldi 29
		plo rLoDxCorr
drawLoopI:
		inc rScreenYAdr
		ghi rHiDeltaX
		add
		str rDataPointer
		bdf drawIfMarkI
		dec rLoDxCorr
drawIfMarkI:
		lda rMarksWidthY
		bz drawLoopI
		glo rLoDxCorr
		shl
        sex rScreenYAdr
        add
		plo r15h_PixelData
		dec rMarksWidthY
		sex rMarksWidthY
		add
		plo r14h_PixelData
		inc rMarksWidthY
		;calc screen offset for left road border
		lda r14h_PixelData
		sd
		plo rRowAdr
		ldn r14h_PixelData
		str rRowAdr				;put pixel
		;calc screen offset for right road border
		lda r15h_PixelData
		sd
		plo rRowAdr
		ldn r15h_PixelData
		str rRowAdr 			;put pixel

		lda rMarksWidthY
		add
		sex rDataPointer
		bnz drawLoopI
drawRoadEnd:
		inc rMarksWidthY

		
		ldi <mRoadStartAdr
		plo rDataPointer
		glo rRoadSectorAdr
		sm
		bz drawFinishLine
		dec rDataPointer
		sm
		bnz drawCar

		inc rDataPointer
		inc rDataPointer
		ldn rDataPointer
		dec rDataPointer
		adi 256-START_PERSPECTIVE_Y
		bnf drawFinishLine
		ldi 12
		plo rGlobalState

drawFinishLine:
		inc rDataPointer
		sex rRowAdr
		ldn rDataPointer
		shl
		shl
		shl
		adi 15
		plo rRowAdr
		adi 196
		ldi 0x55
		bnf drawFinishOneLine

drawFinishLineLoop:
		stxd
		stxd
		stxd
		stxd
		stxd
		stxd
		stxd
		stxd
drawFinishOneLine:
		shl
		bnf drawFinishLineLoop
		ldi 0
		stxd
		stxd
		stxd
		stxd
		stxd
		stxd
		stxd
		stxd
		inc rRowAdr

drawCar:
		sex rRowAdr
		ldn rMarksWidthY
		plo rMarksWidthY
		ldi >btmCar
		phi r3Buf
		
		glo rLoWheel
		bz drawCarCenter
		shl
		ldi <btmCarLeft
		bnf drawCarLeft
		ldi <btmCarRight
		br drawCarRight
drawCarCenter:
		ldi <btmCarCenter
drawCarLeft:
		plo r3Buf
		lda r3Buf
drawCarTopLoop:
		plo rRowAdr
		lda r3Buf
		or
		stxd
		lda r3Buf
		or
		stxd
		lda r3Buf
		bnz drawCarTopLoop

		ldi <btmCar
drawCarRight:
		plo r3Buf
		lda r3Buf
drawCarLoop:
		plo rRowAdr
		lda r3Buf
		stxd
		lda r3Buf
		stxd
		lda r3Buf
		bnz drawCarLoop

		
		ghi rHiSpeed
		smi 3
		bnf waitVsync
		ghi rHiCounter
		ani 0x02
		bz waitVsync
		ldi 220
		plo rRowAdr
		ldi 10110000b
		stxd
		ldi 00001101b
		stxd



waitVsync:					;wait 1861 interrupt
		sex r1
		ret
		.db  $21
		idl
		lbr displayRefresh



		.org $300
displayRefresh:
		ldi <btmTopText
		plo r0
		ldi >btmTopText
		phi r0
		;any code <21 cicles, cicles count mast be a multiple by 3
displayWait0:
		sex rDataPointer
		glo r0
		smi <(8*5+btmTopText-16)
		bnz displayWait0
		ldi >zero128b

		;draw 3 space after digits
		phi r0
		ldi <zero128b
		plo r0

updateTimer:
		;should take 5 cycles
		glo rLoTimer
		ani 0x0F
		bz fixTimer
		skp
fixTimer:	
		inc rLoTimer
incTimer:	
		inc rLoTimer

		ldi >mBtmDigits

		;first digits line in 128
		phi r0
		ldi <mBtmDigits
		plo r0

		;second line in 64
		ghi r1
		phi r3Buf
		glo r0

		plo r0
		ldi <displayWait1
		plo r3Buf

		;third line in 128 
		sex rDataPointer
		sex rDataPointer
		sep r3Buf

		;fourth and fifth line in 64
displayWait1:
		sex rDataPointer
		sex rDataPointer
		glo r0
		
		plo r0
		ldi >zero128b
		sep r1

		;draw space after digits
		phi r0
		ldi <zero128b
		plo r0

displayWait2:
		glo r0
		smi 240
		bnz displayWait2

		ldi <152
		plo r0
		sex rDataPointer
displayWait3:
		glo r0
		smi 248
		bnz displayWait3

		;draw horizon
		ldi <mBtmHorizonStart
		plo r0
		
displayWait4:	
		glo r0
		smi 240
		bnz displayWait4

		;draw space after horizon
		ldi >zero128b
		phi r0

		ldi 224
		plo r0
displayWait5:
		glo r0
		smi 248
		bnz displayWait5
		
		;sex rDataPointer ;need del inc rLoTimer
		;glo rLoTimer ;for gray bkg, need ldi 13
		;shr
		;bdf displayTest ;$+6
		;ldi >$E00
		;phi r0
		;br displayTest2

		;draw road in 64
displayTest:
		ldi >(RAM+256)
displayTest2:
		phi r0
displayWait6:
		glo r0
		dec r0
		plo r0
		sex rDataPointer
		smi 248
		bnz displayWait6

main:

checkGlobalState:
		glo rGlobalState
		lbnz selectGlobalState

updateSpeed:
		glo rloSpeedCounter
		bz resetSpeedCounter
		shl
		bdf incSpeedCounter
decSpeedCounter:
		dec rloSpeedCounter
		br moreCalledAtHigherSpeed
resetSpeedCounter:
		ghi rloSpeedCounter
		smi 10							;define start speed, lower - faster
		plo rloSpeedCounter
		bnf moreCalledAtHigherSpeed
incSpeedCounter:
		inc rloSpeedCounter				;rHiSpeed may be corrupted but it will be set in scanAccelKey
		
lessCalledAtHigherSpeed:
		lbr scanAccelKey

moreCalledAtHigherSpeed:
		ghi rHiCounter
		adi 1
		phi rHiCounter
		shr
		lbnf drawRoad ;drawRoad every second frame


scanTurnKey:
		glo rLoWheel 
		adi WHEEL_LIMIT
		adi 255-WHEEL_LIMIT*2
		glo rLoWheel 
		bdf noKey
		sex r1
		out 2
		.db 6
		b4 decrKey
		out 2
		.db 4
		b4 incrKey
noKey:
		bz scanTurnKeyEnd
		shl
		glo rLoWheel 
		bnf decrKey
incrKey:
		adi 2
decrKey:
		smi 1
		plo rLoWheel
scanTurnKeyEnd:


		ghi rHiSpeed
		lbz waitVsync

		lbr calcRoadOrShiftHorizon
	

		.org $500
calcRoadOrShiftHorizon:


updateCarX:
		ldi <mData
		plo rDataPointer
		sex rDataPointer
		ghi rHiCarX
		str rDataPointer
		glo rLoWheel
		shl
		glo rLoWheel
		shrc
		add
		str rDataPointer
		ldn rRoadSectorAdr
		add							;add road sector -1..-3 or 1..3
		str rDataPointer
		
		ghi rHiSpeed
		smi SPEED_SKID_START
		bnf skipDecCarX
		shr
		shr
		plo r4buf
		ldn rRoadSectorAdr
		bz skipDecCarX
		shl
		glo r4buf
		bnf incCarX
		sd
		skp
incCarX:
		add
		str rDataPointer

skipDecCarX:
		ldn rDataPointer
storeCarX:
		adi CAR_X_LIMIT				;range check, right limit
		adi 255-CAR_X_LIMIT*2				;last - left limit
		ldn rDataPointer
		bnf saveNewCarX
		shl
		ldi -CAR_X_LIMIT
		bdf saveNewCarX
		ldi CAR_X_LIMIT
saveNewCarX:
		phi rHiCarX


		;shift horizon and calc road curve every fourth frame
		ghi rHiCounter
		shr
		shr
		lbnf shiftHorizon


calcRoad:
		;122 cicles free
		ldi <mData
		plo rDataPointer		;X to ddx
		
		plo r5Buf
		ghi rDataPointer
		phi r5Buf

		ldi <(MAX_SEGMENT_Y+1)
		plo rScreenYAdr
		
		ldi 0
		stxd 					;ddx = 0; X to dx.0
		stxd 					;dx.0 = 0; X to dx.1
		stxd					;dx.1 = 0; X to mPerspectiveYBuf

		dec rDataPointer		;to mPerspectiveY
updatePerspectiveY:
		lda rDataPointer
		smi MAX_SEGMENT_Y
		bnf incPerspectiveY
clearPerspectiveY:
		ldi -MAX_SEGMENT_Y-1
		inc rRoadSectorAdr
incPerspectiveY:
		adi MAX_SEGMENT_Y+1
		stxd					;new mPerspectiveY to mPerspectiveYBuf
		stxd					;and to mPerspectiveY

calcRoadLoop:
		glo r5Buf
		plo rDataPointer
		ldn rRoadSectorAdr
		add
		stxd ;new ddx; X to dx.0
		
		add
		stxd						;new dx.0; X to dx.1
		ani 0xE0
		str rScreenYAdr
		ldn r5Buf
		ani 0x80
		bz $+4
		ldi 0xFF
		adc
		stxd						;new dx.1; X to mPerspectiveY

		ani 0x0F
		shr
		sex rScreenYAdr
		or
		shrc
		shrc
		shrc
		shrc
		stxd						;save to rScreenYAdr and dec it

		sex rDataPointer
		glo rScreenYAdr
		sm 						;compare rScreenYAdr with mPerspectiveY
		bnz calcRoadLoop

		stxd 	;clear mPerspectiveYBuf
		glo rScreenYAdr
		bz calcRoadExit
		inc rRoadSectorAdr
		br calcRoadLoop

calcRoadExit:
		ldx
		bz calcRoadEnd
		dec rRoadSectorAdr
calcRoadEnd:
		lbr waitVsync; incScoresAndSegment


shiftHorizon:
		ghi rDataPointer
		phi r5Buf
		ldn rRoadSectorAdr
		shl
		bdf shiftRightHorizon
		bz shiftHorizonEnd

shiftLeftHorizon:
		ldi <(mBtmHorizonEnd)
		plo rDataPointer

		ldi <(mBtmHorizonEnd-7)
		plo r5Buf
shiftLeftHorizonLoop:
		ldn r5Buf
		shlc

loop:
		ldx
		shlc
		stxd
		ldx
		shlc
		stxd
		ldx
		shlc
		stxd
		ldx
		shlc
		stxd
		glo rDataPointer
		ani 0x04
		bz loop

		glo r5Buf
		smi 8
		plo r5Buf

		shl
		bdf shiftLeftHorizonLoop
		br shiftHorizonEnd

shiftRightHorizon:
		ldi <(mBtmHorizonStart)
		plo r5Buf
		
		ldi <(mBtmHorizonStart+7)
shiftRightHorizonLoop:
		plo rDataPointer
		ldn rDataPointer
		shrc

		ldn r5Buf
		shrc      
		str r5Buf
		inc r5Buf
		ldn r5Buf
		shrc
		str r5Buf
		inc r5Buf
		ldn r5Buf
		shrc
		str r5Buf
		inc r5Buf
		ldn r5Buf
		shrc
		str r5Buf
		inc r5Buf
		ldn r5Buf
		shrc
		str r5Buf
		inc r5Buf
		ldn r5Buf
		shrc
		str r5Buf
		inc r5Buf
		ldn r5Buf
		shrc
		str r5Buf
		inc r5Buf
		lda r5Buf
		shrc
		str rDataPointer

		glo rDataPointer
		adi 8
		bnf shiftRightHorizonLoop
shiftHorizonEnd:

incStores:
		ldi <(mScoreLow+1)
		plo rDataPointer
		ldx
incStoresLoop:
		stxd
		ldi 1
		add
		str rDataPointer
		smi 10
		bdf incStoresLoop
		
drawScore:
		ldi <(mScoreSpace+4)
		plo rDataPointer
		ldi <(digitsPos+4+2)
		plo r3Buf
		lbr drawString



		.org $600
selectGlobalState:
		smi 3
		bnf prepareLevelStep	  ;state = 1-2
		smi 8
		bnf globalStateCountDown  ;state = 3-10
		bz startRace			  ;state = 11
		smi 1
		bz finishRoad			  ;state = 12
	
		;state other
gameOver:						  
		lbr waitVsync
		

prepareLevelStep:
		inc rGlobalState

		adi 1
		lbz drawRoad 			; if state = 2

		;put zeros
		ldi 0
		phi rHiCarX
		plo rLoWheel
		plo rloSpeedCounter
		phi rHiSpeed

loadHorizon:
		lda rRoadSectorAdr
		phi r5Buf
		lda rRoadSectorAdr
		plo r5Buf
		ldi <mRoadStartAdr
		plo rDataPointer
		lda rRoadSectorAdr
		stxd
		lda rRoadSectorAdr
		stxd
		
		ldi <mBtmHorizonEnd
		plo rDataPointer
loadHorizonLoop:
		lda r5Buf
		stxd
		bnz notZero
		;simple comress: if 0 then read next byte for get zeros count
		lda r5Buf
		bz notZero
		plo r4buf
storeZeros:
		ldi 0
		stxd
		dec r4buf
		glo r4buf
		bnz storeZeros
notZero:
		glo rDataPointer
		shl
		bdf loadHorizonLoop
		
		ldi <mPerspectiveY
		plo rDataPointer
		ldi START_PERSPECTIVE_Y
		stxd

initTopInfo:
		ldi <mScoreSpace
		plo rDataPointer
		ldi <chr_
		stxd
		stxd
		ldi <chr0+<TIMER_START_LO
		stxd
		ldi <chr0+<TIMER_START_HI
		stxd
		ldi <chr_
		stxd
		stxd
		ldi <chr0
		stxd
		stxd
		stxd
		;todo: need more cicles
		lbr waitVsync

		
startRace:
		;put zeros
		plo rGlobalState
		phi rHiCounter
		lbr drawRoad


rRowAdr = r5Buf
clearLight:
		ldi 0
		stxd
		glo rRowAdr
		bnz clearLight
		br globalStateCountDownEnd
		
globalStateCountDown:

		;every 0.75s
		glo rLoTimer
		adi 208
		lbnf drawSpeedAndTimer
		glo rLoTimer
		ani 0x0F
		plo rLoTimer

		ldi >(RAM+256)
		phi rRowAdr
		ldi LIGHT_POSITION_Y
		plo rRowAdr	
		sex rRowAdr

		inc rGlobalState
		glo rGlobalState
		smi 11
		bz clearLight
		shl
		shl
		adi <btmLight0
		plo r4Buf

		ldi >btmLightTop
		phi r3Buf
		ldi <btmLightTop
		plo r3Buf

drawLight:
		lda r3Buf
		stxd
		lda r3Buf
		stxd
		lda r3Buf
		stxd		
		lda r3Buf
		stxd
		glo rRowAdr
		smi 4
		plo rRowAdr
		adi (8*2+256-LIGHT_POSITION_Y)
		bdf drawLight
		adi (8*3)
		bnf drawLightBottom
		glo r4Buf
		plo r3Buf
		br drawLight
drawLightBottom:
		adi (8*1)
		bnf drawLightEnd		
		ldi <btmLightBottom
		plo r3Buf
		br drawLight
drawLightEnd:
		adi (8*2)
		bdf drawLight
		
globalStateCountDownEnd:
		lbr waitVsync
		

finishRoad:
		inc rRoadSectorAdr
		inc rRoadSectorAdr
		ldi 1
		plo rGlobalState
		lbr waitVsync

btmLightTop:
		.db 11111110b, 11111111b, 11111111b, 01111111b
		.db 00000001b, 00000000b, 00000000b, 10000000b
btmLightBottom:
		.db 00011001b, 10000110b, 01100001b, 10011000b
		.db 00000001b, 00000000b, 00000000b, 10000000b
		.db 11111110b, 11111111b, 11111111b, 01111111b
	
		.db 00100101b, 01001001b, 10010010b, 10100100b	
		.db 00100101b, 01001001b, 10010010b, 10111100b
		.db 00100101b, 01001001b, 11110010b, 10111100b
		.db 00100101b, 11001001b, 11110011b, 10111100b
		.db 00100101b, 11001111b, 11110011b, 10111100b
		.db 00111101b, 11001111b, 11110011b, 10111100b
		.db 00100101b, 01001001b, 10010010b, 10100100b	
btmLight0:
		
		.org $700
pixelData:
		.db 7,0x80, 7,0x40, 7,0x20, 7,0x10, 7,0x08, 7,0x04, 7,0x02, 7,0x01
		.db 6,0x80, 6,0x40, 6,0x20, 6,0x10, 6,0x08, 6,0x04, 6,0x02, 6,0x01
		.db 5,0x80, 5,0x40, 5,0x20, 5,0x10, 5,0x08, 5,0x04, 5,0x02, 5,0x01
		.db 4,0x80, 4,0x40, 4,0x20, 4,0x10, 4,0x08, 4,0x04, 4,0x02, 4,0x01
		.db 3,0x80, 3,0x40, 3,0x20, 3,0x10, 3,0x08, 3,0x04, 3,0x02, 3,0x01
		.db 2,0x80, 2,0x40, 2,0x20, 2,0x10, 2,0x08, 2,0x04, 2,0x02, 2,0x01
		.db 1,0x80, 1,0x40, 1,0x20, 1,0x10, 1,0x08, 1,0x04, 1,0x02, 1,0x01
		.db 0,0x80, 0,0x40, 0,0x20, 0,0x10, 0,0x08, 0,0x04, 0,0x02, 0,0x01
zero128b:
		.ds 128, 0		  ;for out of screen


		;RAM
		;.org 800
		;.org 900
		;.org a00 - blocked for multicart
		;.org b00 - blocked for multicart

		.org $C00
chr0:	.db <btm0, <btm1, <btm2, <btm3, <btm4, <btm5, <btm6, <btm7, <btm8, <btm9
chr_:	.db <btm_
chrR:	.db <btmR
chrE:	.db <btmE
chrV:	.db <btmV ;5 zeros for space

btm_:	.db 0,0,0,0,0
btm1:	.db 11001100b
		.db 01000100b
		.db 01000100b
		.db 01000100b
btmE:	.db 11101110b
		.db 10001000b
btm6:	.db 11101110b
		.db 10001000b
btm8:	.db 11101110b
		.db 10101010b
btm9:	.db 11101110b
		.db 10101010b
btm2:	.db 11101110b
		.db 00100010b
btm5:	.db 11101110b
		.db 10001000b
		.db 11101110b
		.db 00100010b
btm3:	.db 11101110b
		.db 00100010b
		.db 01100110b
		.db 00100010b
btmO:
btm0:	.db 11101110b
btm4:	.db 10101010b
		.db 10101010b
		.db 10101010b
btm7:	.db 11101110b
		.db 00100010b
		.db 01000100b
		.db 01000100b
		.db 01000100b

btmR:	.db 11001100b
		.db 10101010b
		.db 11001100b
btmV:	.db 10101010b
		.db 10101010b
		.db 10101010b
		.db 10101010b
		.db 01000100b

digitsPos:
		.db <mBtmDigits,<mBtmDigits+1,<mBtmDigits+3,<mBtmDigits+4,<mBtmDigits+5,<mBtmDigits+6,<mBtmDigits+7, 0

btmCarCenter:
		.db 196, 01011100b,00111010b
		.db 204, 11111100b,00111111b
		.db 212, 00001100b,00110000b, 0
btmCarLeft:
		.db 196, 01111000b,01110010b
		.db 204, 11111000b,01111111b
		.db 212, 00001000b,01110000b, 0
btmCarRight:
		.db 196, 01001110b,00011110b
		.db 204, 11111110b,00011111b
		.db 212, 00001110b,00010000b
btmCar:
		.db 188, 10000000b,00000001b
		.db 220, 10111111b,11111101b
		.db 228, 11111111b,11111111b
		.db 236, 01011111b,11111010b
		.db 244, 11101111b,11110111b
		.db 252, 00001111b,11110000b, 0
			
btmTopText:
		.db 01101100b, 11101110b, 11000000b, 01110101b, 01011100b, 00000110b, 11101110b, 11001110b
		.db 10001010b, 10001000b, 10100000b, 00100101b, 11010000b, 00001000b, 10001010b, 10101000b
		.db 01101010b, 11001100b, 10100000b, 00100101b, 01011000b, 00000110b, 10001010b, 10101100b
		.db 00101100b, 10001000b, 10100000b, 00100101b, 01010000b, 00000010b, 10001010b, 11001000b
		.db 11001000b, 11101110b, 11000000b, 00100101b, 01011100b, 00001100b, 11101110b, 10101110b

		
		.org $D00	

marksWidthY:
		; 1 - pixel offset from center *2 ; 2 - modifier for pixelData table 65 41 17 1
m1: 	.db 16,7,00000,24,23,00000,00000,36,47,00000,00000,00000,52,79,56,87,00000,000000,68,111,72,119,76,127,000000,000000,000000,000000,96,167,100,175,104,183,108,191,112,199, 57, <m1, <m2
m2: 	.db 16,7,00000,24,23,00000,00000,00000,40,55,00000,00000,00000,56,87,60,95,000000,000000,000000,76,127,80,135,84,143,000000,000000,000000,0000000,0,108,191,112,199,116,207,120,215, 41, <m2, <m3
m3: 	.db 16,7,00000,00000,28,31,00000,00000,00000,44,63,00000,00000,00000,60,95,64,103,000000,000000,000000,000000,84,143,88,151,92,159,000000,0000000,0,0,0,0,120,215,124,223,128,231,132,239, 17, <m3, <m4
m4: 	.db 16,7,20,15,00000,00000,32,39,00000,00000,00000,48,71,00000,00000,00000,64,103,68,111,000000,000000,000000,000000,000000,92,159,96,167,0000000,0,0,0,0,0,0,0,132,239,136,247,140,255, 1, <m4, <m1


roadData1:
		.db >btmMountains, <btmMountains, <startRoad1, <(finishRoad1-startRoad1)
startRoad1:
		.db 0, 0, 0, 0, 2, 2,-2,-2, 0, 0, 0, 2, 3, 2, 0,-3,-3, 0, 0, 0, 1, 1, 0, 2, 2, 0, 1, 0, 0
finishRoad1:
		.db 0, 0

roadData2:
		.db >btmFudji, <btmFudji, <startRoad2, <(finishRoad2-startRoad2)
startRoad2:
		.db 0, 0, 0, 0, 0, 0, 2, 2, 0, 3,-3, 0, 0, 2,-2, 1,-1, 0, 0,-2,-1, 0, 0, 1, 1, 2, 2, 0, 0
finishRoad2:
		.db 0, 0

		.org $E00
btmFudji:
		.db 0x04, 0x10, 0x34, 0x44, 0x23, 0x48, 0x02, 0x41
		.db 0x22, 0x21, 0x48, 0xaa, 0x54, 0x24, 0x91, 0x90
		.db 0xf7, 0x52, 0x95, 0x11, 0x88, 0x82, 0xfb, 0xf9
		.db 0x7d, 0x8d, 0x22, 0x82, 0x44, 0xc5, 0xff, 0xff
		.db 0xb8, 0x02, 0x40, 0x44, 0x22, 0xa8, 0xf7, 0x9d
		.db 0x10, 0x01, 0x80, 0x10, 0x10, 0x10, 0xe3, 0x08
		.db 0x00, 0x02, 0xcd, 0x08, 0x00, 0x00, 0x40, 0x00
		.db 0x03, 0xeb, 0x0d, 0x00, 0x05, 0xde, 0x06, 0x00
		.db 0x05, 0xfc, 0x02, 0x00, 0x05, 0x7c, 0x03, 0x00
		.db 0x05, 0xf8, 0x01, 0x00, 0x05, 0xf8, 0x01, 0x00
		.db 0x05, 0xf0, 0x00, 0x06, 0xf0, 0x00, 0x06, 0xf0
		.db 0x00, 0x03
btmMountains:
		.db 0x01,0x00,0x06
		.db 0x03,0x00,0x05,0x80
		.db 0x07,0x00,0x05,0xC0
		.db 0x0F,0x00,0x05,0xE0
		.db 0x1F,0x00,0x05,0xF0
		.db 0x3F,0x00,0x01,0x02,0x00,0x02,0xF8
		.db 0x7F,0x00,0x01,0x0F,0x00,0x02,0xFC
		.db 0xFF,0x00,0x00,0x80,0x3F,0x00,0x01,0x01,0xFE
		.db 0xFF,0x01,0xC0,0xFF,0x00,0x00,0xC0,0x03,0xF9
		.db 0xFF,0x03,0xE0,0xFF,0x03,0xF0,0x87,0xF0
		.db 0xFF,0x04,0xF0,0xFF,0x0F,0xFC,0x4B,0xE0
		.db 0x3F,0x08,0xF8,0xFF,0x37,0xF3,0x31,0xC0
		.db 0x0F,0x10,0xE4,0xFF,0xC1,0xE0,0x00,0x00,0x80
		.db 0x03,0x20,0x82,0x7F,0x00,0x00,0x40,0x00,0x02
		.db 0x40,0x01,0x1E,0x00,0x04
		.db 0x80,0x00,0x05



		.org $F00

menuWaitVsync:					;wait 1861 interrupt
		sex r1
		ret
		.db  $21
		idl
		nop
menuDisplayRefresh:
		ldi <btmCaption
		plo r0
		ldi >btmCaption
		phi r0

		ldi 30
		plo r3Buf
menuDisplayWait0:
		sex rDataPointer
		ldi <btmCaption
		plo r0
		dec r3Buf
		glo r3Buf
		bnz menuDisplayWait0

menuDisplayWait1:
		glo r0
		smi <(btmCaptionEnd-8)
		bnf menuDisplayWait1

		ldi 30
		plo r3Buf
menuDisplayWait2:
		sex rDataPointer
		ldi <btmCaption
		plo r0
		dec r3Buf
		glo r3Buf
		bnz menuDisplayWait2

		ldi >RAM
		phi rDataPointer
		ldi <mData
		plo rDataPointer
		ldi 10
menuReadAnyKey:
		smi 1
		str rDataPointer
		out 2
		b4 menuExit
		dec rDataPointer
		ldx
		bnz menuReadAnyKey


		br menuWaitVsync

menuExit:
		lbr waitVsync

btmCaption:
		.db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
		.db 0x00, 0xf7, 0xd9, 0x3c, 0x1e, 0x79, 0xe7, 0x80
		.db 0x01, 0x90, 0xd9, 0x64, 0x32, 0xcb, 0x2c, 0x80
		.db 0x01, 0x91, 0x99, 0x64, 0x02, 0xd8, 0x2d, 0x80
		.db 0x01, 0xf3, 0x0e, 0x7c, 0x3e, 0xeb, 0xee, 0x80
		.db 0x01, 0x96, 0x06, 0x64, 0x30, 0xcb, 0x0c, 0x80 
		.db 0x01, 0x96, 0x06, 0x65, 0x30, 0xcb, 0x0c, 0x80
		.db 0x01, 0x97, 0xc6, 0x65, 0x3e, 0xfb, 0xef, 0x80
		.db 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00
btmCaptionEnd:
		.db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
		.org 0xfff
		.db 0xff
		.end

		
