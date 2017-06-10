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

    inc z:framecount
        
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
framecount: .res 1


    .segment "CODE"
main:
    lda #$00
    sta z:framecount
@loopforever:
    jmp @loopforever
    rts
