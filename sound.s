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
nmi:
    pha
    txa
    pha
    tya
    pha

    dec z:countdown
    bne @complete

@findnote:
    ldx z:notedex
    lda GroundM_P1Data, x
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

    .segment "CODE"

playnote:
    tax
    lda #$01
    sta $4015
    lda Freqencies+1,x
    sta $4002
    lda Freqencies+0,x
    ora #$b0
    sta $4003
    lda #$ca  ; 1011|1111
    sta $4000
    rts

main:
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

GroundM_P1Data:
.byte $85, $2c, $22, $1c, $84, $26, $2a, $82, $28, $26, $04
.byte $87, $22, $34, $3a, $82, $40, $04, $36, $84, $3a, $34
.byte $82, $2c, $30, $85, $2a
