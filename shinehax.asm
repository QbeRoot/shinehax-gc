bl -0x4011CC # OSDisableInterrupts

# set up a stack frame
lis sp, 0x8000
ori sp, sp, 0x3000
li r0, 0
stwu r0, -0x40(sp)

bl -0x3E8FE8 # GXSetDrawDone
bl -0x4011D0 # OSEnableInterrupts

# replace gameid
lis r31, 0x8000
lis r0, 0x444F
ori r0, r0, 0x4C58
stw r0, 0x0(r31)
li r0, 0x3030
sth r0, 0x4(r31)

# move loader somewhere safe
ori r3, r31, 0x1800
lis r30, 0x8073
ori r4, r30, 0xED0C  # loader
li r5, 0x41C
bl -0x73BA48 # memcpy

# sync up
dcbst r0, r31
li r5, 0x400 # sizeof loader & ~0x1F
dcbst r3, r5
icbi r3, r5
subic. r5, r5, 0x20
bge+ -0xC
isync
sync

# get boot.dol from the memory card
li r3, 0
ori r4, r30, 0xF260
li r5, 0
bl -0x3EE170 # CARDMount

li r3, 0
ori r4, r30, 0xEA8D  # "boot.dol"
addi r5, sp, 0x8
bl -0x3ED6D0 # CARDOpen

li r29, 0

readloop:
addi r3, sp, 0x8
ori r4, r31, 0x2800
li r5, 0x200
mr r6, r29
bl -0x3ECD54 # CARDRead
cmpwi r3, 0
bne- readloop_end
ori r3, r31, 0x2800
li r5, 0x1E0
dcbst r3, r5
subic. r5, r5, 0x20
bge+ -0x8
sync

# AR DMA
lis r4, 0xCC00
rlwinm r0, r3, 16, 16, 31
sth r0, 0x5020(r4)
sth r3, 0x5022(r4)
rlwinm r0, r29, 16, 16, 31
sth r0, 0x5024(r4)
sth r29, 0x5026(r4)
li r0, 0
sth r0, 0x5028(r4)
li r0, 0x200
sth r0, 0x502A(r4)
lhz r0, 0x500A(r4)
andi. r0, r0, 0x200
bne+ -0x8

addi r29, r29, 0x200
b readloop

readloop_end:
addi r3, sp, 0x8
bl -0x3ED5D8 # CARDClose
ori r3, r31, 0x1800
mtlr r3
blr