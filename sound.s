PPUCTRL = $2000
PPUMASK = $2001
PPUSTAT = $2002
OAMADDR = $2003
PPUSCRL = $2005
PPUADDR = $2006
PPUDATA = $2007


    .segment "HEADER"

INES_MAPPER = 0 ; 0 = NROM
INES_MIRROR = 1 ; 0 = horizontal mirroring, 1 = vertical mirroring
INES_SRAM   = 0 ; 1 = battery backed SRAM at $6000-7FFF

.byte 'N', 'E', 'S', $1A ; ID
.byte $02 ; 16k PRG bank count
.byte $01 ; 8k CHR bank count
.byte INES_MIRROR | (INES_SRAM << 1) | ((INES_MAPPER & $f) << 4)
.byte (INES_MAPPER & %11110000)
.byte $0, $0, $0, $0, $0, $0, $0, $0 ; padding


    .segment "TILES"
.res 8 * 2 * 256
.res 8 * 2 * 256



    .segment "VECTORS"
.word nmi
.word reset
.word irq


    .segment "OAM"
oam: .res 256        ; sprite OAM data to be uploaded by DMA


    .segment "CODE"
reset:
    sei        ; ignore IRQs
    cld        ; disable decimal mode
    ldx #$40
    stx $4017  ; disable APU frame IRQ
    ldx #$ff
    txs        ; Set up stack
    inx        ; now X = 0
    stx PPUCTRL
    stx PPUMASK
    stx $4010  ; disable DMC IRQs
    ; wait for first vblank
    bit PPUSTAT
@vblankwait1:
    bit PPUSTAT
    bpl @vblankwait1

    ; clear all RAM to 0
    lda #0
    ldx #0
@clearmem:
    sta $0000, x
    sta $0100, x
    sta $0300, x
    sta $0400, x
    sta $0500, x
    sta $0600, x
    sta $0700, x
    inx
    bne @clearmem

    tay
    lda #$f8
@clearsprites:
    sta oam, x
    inx
    bne @clearsprites

    tya  ; At this point A, X, and Y registers are all zero
    ; wait for second vblank
@vblankwait2:
    bit $2002
    bpl @vblankwait2

    ;  Ready to initialize
    lda #%10000000
    sta PPUCTRL
    jmp main


    .segment "CODE"

playsquare2:
    dec z:countdown
    bne @complete

@findnote:
    ldy z:notedex
    lda (musicaddr), y
    bne @interpret

    sta z:notedex ; reset notedex to zero
    inc z:sectionindex
    ldx z:sectionindex
    jsr setsection
    jmp @findnote

@interpret:
    inc z:notedex
    tax
    and #$80
    beq @notefound
    ; Set the note length
    txa
    and #$07
    clc
    adc #$18
    tax
    lda MusicLengthLookupTbl, x
    sta z:notelen
    jmp @findnote

@notefound:
    txa
    jsr playnote

    lda z:notelen
    sta z:countdown
        
@complete:
    rts

nmi:
    pha
    txa
    pha
    tya
    pha

    jsr playsquare2

    pla
    tay
    pla
    tax
    pla
    rti

irq:
    rti


    .segment "ZEROPAGE"
countdown: .res 1
notelen: .res 1
notedex: .res 1
musicaddr: .res 2
sectionindex: .res 1

    .segment "CODE"

playnote:
    tax
    lda #$01
    sta $4015
    lda Freqencies+1,x
    sta $4002
    lda Freqencies+0,x
    ora #$80
    sta $4003
    lda #$9f
    sta $4000
    rts

setsection:
    lda MusicHeaderData, x
    tax
    lda MusicHeaderData+1, x
    sta musicaddr
    lda MusicHeaderData+2, x
    sta musicaddr+1
    rts

main:
    ldx #$00
    stx sectionindex
    jsr setsection

    lda #$01
    sta z:countdown
@loopforever:
    jmp @loopforever
    rts

.RODATA
; Frequency tables stolen from Super Mario Brothers
;
Freqencies: ; len = 54
.byte $00, $88, $00, $2f, $00, $00
.byte $02, $a6, $02, $80, $02, $5c, $02, $3a
.byte $02, $1a, $01, $df, $01, $c4, $01, $ab
.byte $01, $93, $01, $7c, $01, $67, $01, $53
.byte $01, $40, $01, $2e, $01, $1d, $01, $0d
.byte $00, $fe, $00, $ef, $00, $e2, $00, $d5
.byte $00, $c9, $00, $be, $00, $b3, $00, $a9
.byte $00, $a0, $00, $97, $00, $8e, $00, $86
.byte $00, $77, $00, $7e, $00, $71, $00, $54
.byte $00, $64, $00, $5f, $00, $59, $00, $50
.byte $00, $47, $00, $43, $00, $3b, $00, $35
.byte $00, $2a, $00, $23, $04, $75, $03, $57
.byte $02, $f9, $02, $cf, $01, $fc, $00, $6a

MusicLengthLookupTbl:
.byte $05, $0a, $14, $28, $50, $1e, $3c, $02
.byte $04, $08, $10, $20, $40, $18, $30, $0c
.byte $03, $06, $0c, $18, $30, $12, $24, $08
.byte $36, $03, $09, $06, $12, $1b, $24, $0c
.byte $24, $02, $06, $04, $0c, $12, $18, $08
.byte $12, $01, $03, $02, $06, $09, $0c, $04

MusicHeaderData:
MHD:

.byte GroundLevelLeadInHdr-MHD  ;ground level music layout
.byte GroundLevelPart1Hdr-MHD, GroundLevelPart1Hdr-MHD
.byte GroundLevelPart2AHdr-MHD, GroundLevelPart2BHdr-MHD, GroundLevelPart2AHdr-MHD, GroundLevelPart2CHdr-MHD
.byte GroundLevelPart2AHdr-MHD, GroundLevelPart2BHdr-MHD, GroundLevelPart2AHdr-MHD, GroundLevelPart2CHdr-MHD
.byte GroundLevelPart3AHdr-MHD, GroundLevelPart3BHdr-MHD, GroundLevelPart3AHdr-MHD, GroundLevelLeadInHdr-MHD
.byte GroundLevelPart1Hdr-MHD, GroundLevelPart1Hdr-MHD
.byte GroundLevelPart4AHdr-MHD, GroundLevelPart4BHdr-MHD, GroundLevelPart4AHdr-MHD, GroundLevelPart4CHdr-MHD
.byte GroundLevelPart4AHdr-MHD, GroundLevelPart4BHdr-MHD, GroundLevelPart4AHdr-MHD, GroundLevelPart4CHdr-MHD
.byte GroundLevelPart3AHdr-MHD, GroundLevelPart3BHdr-MHD, GroundLevelPart3AHdr-MHD, GroundLevelLeadInHdr-MHD
.byte GroundLevelPart4AHdr-MHD, GroundLevelPart4BHdr-MHD, GroundLevelPart4AHdr-MHD, GroundLevelPart4CHdr-MHD

GroundLevelPart1Hdr:  .byte $18, <GroundM_P1Data, >GroundM_P1Data, $2d, $1c, $b8
GroundLevelPart2AHdr: .byte $18, <GroundM_P2AData, >GroundM_P2AData, $20, $12, $70
GroundLevelPart2BHdr: .byte $18, <GroundM_P2BData, >GroundM_P2BData, $1b, $10, $44
GroundLevelPart2CHdr: .byte $18, <GroundM_P2CData, >GroundM_P2CData, $11, $0a, $1c
GroundLevelPart3AHdr: .byte $18, <GroundM_P3AData, >GroundM_P3AData, $2d, $10, $58
GroundLevelPart3BHdr: .byte $18, <GroundM_P3BData, >GroundM_P3BData, $14, $0d, $3f
GroundLevelLeadInHdr: .byte $18, <GroundMLdInData, >GroundMLdInData, $15, $0d, $21
GroundLevelPart4AHdr: .byte $18, <GroundM_P4AData, >GroundM_P4AData, $18, $10, $7a
GroundLevelPart4BHdr: .byte $18, <GroundM_P4BData, >GroundM_P4BData, $19, $0f, $54
GroundLevelPart4CHdr: .byte $18, <GroundM_P4CData, >GroundM_P4CData, $1e, $12, $2b

GroundM_P1Data:
.byte $85, $2c, $22, $1c, $84, $26, $2a, $82, $28, $26, $04
.byte $87, $22, $34, $3a, $82, $40, $04, $36, $84, $3a, $34
.byte $82, $2c, $30, $85, $2a

SilenceData:
.byte $00

.byte $5d, $55, $4d, $15, $19, $96, $15, $d5, $e3, $eb
.byte $2d, $a6, $2b, $27, $9c, $9e, $59

.byte $85, $22, $1c, $14, $84, $1e, $22, $82, $20, $1e, $04, $87
.byte $1c, $2c, $34, $82, $36, $04, $30, $34, $04, $2c, $04, $26
.byte $2a, $85, $22

GroundM_P2AData:
.byte $84, $04, $82, $3a, $38, $36, $32, $04, $34
.byte $04, $24, $26, $2c, $04, $26, $2c, $30, $00

.byte $05, $b4, $b2, $b0, $2b, $ac, $84
.byte $9c, $9e, $a2, $84, $94, $9c, $9e

.byte $85, $14, $22, $84, $2c, $85, $1e
.byte $82, $2c, $84, $2c, $1e

GroundM_P2BData:
.byte $84, $04, $82, $3a, $38, $36, $32, $04, $34
.byte $04, $64, $04, $64, $86, $64, $00

.byte $05, $b4, $b2, $b0, $2b, $ac, $84
.byte $37, $b6, $b6, $45

.byte $85, $14, $1c, $82, $22, $84, $2c
.byte $4e, $82, $4e, $84, $4e, $22

GroundM_P2CData:
.byte $84, $04, $85, $32, $85, $30, $86, $2c, $04, $00

.byte $05, $a4, $05, $9e, $05, $9d, $85

.byte $84, $14, $85, $24, $28, $2c, $82
.byte $22, $84, $22, $14

.byte $21, $d0, $c4, $d0, $31, $d0, $c4, $d0, $00

GroundM_P3AData:
.byte $82, $2c, $84, $2c, $2c, $82, $2c, $30
.byte $04, $34, $2c, $04, $26, $86, $22, $00

.byte $a4, $25, $25, $a4, $29, $a2, $1d, $9c, $95

GroundM_P3BData:
.byte $82, $2c, $2c, $04, $2c, $04, $2c, $30, $85, $34, $04, $04, $00

.byte $a4, $25, $25, $a4, $a8, $63, $04

;triangle data used by both sections of third part
.byte $85, $0e, $1a, $84, $24, $85, $22, $14, $84, $0c

GroundMLdInData:
.byte $82, $34, $84, $34, $34, $82, $2c, $84, $34, $86, $3a, $04, $00

.byte $a0, $21, $21, $a0, $21, $2b, $05, $a3

.byte $82, $18, $84, $18, $18, $82, $18, $18, $04, $86, $3a, $22

;noise data used by lead-in and third part sections
.byte $31, $90, $31, $90, $31, $71, $31, $90, $90, $90, $00

GroundM_P4AData:
.byte $82, $34, $84, $2c, $85, $22, $84, $24
.byte $82, $26, $36, $04, $36, $86, $26, $00

.byte $ac, $27, $5d, $1d, $9e, $2d, $ac, $9f

.byte $85, $14, $82, $20, $84, $22, $2c
.byte $1e, $1e, $82, $2c, $2c, $1e, $04

GroundM_P4BData:
.byte $87, $2a, $40, $40, $40, $3a, $36
.byte $82, $34, $2c, $04, $26, $86, $22, $00

.byte $e3, $f7, $f7, $f7, $f5, $f1, $ac, $27, $9e, $9d

.byte $85, $18, $82, $1e, $84, $22, $2a
.byte $22, $22, $82, $2c, $2c, $22, $04

DeathMusData:
.byte $86, $04 ;death music share data with fourth part c of ground level music 

GroundM_P4CData:
.byte $82, $2a, $36, $04, $36, $87, $36, $34, $30, $86, $2c, $04, $00

.byte $00, $68, $6a, $6c, $45 ;death music only

.byte $a2, $31, $b0, $f1, $ed, $eb, $a2, $1d, $9c, $95

.byte $86, $04 ;death music only

.byte $85, $22, $82, $22, $87, $22, $26, $2a, $84, $2c, $22, $86, $14

;noise data used by fourth part sections
.byte $51, $90, $31, $11, $00
