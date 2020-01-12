# shinehax-gc
A GameCube save exploit for PAL Super Mario Sunshine.

**Make sure 60Hz mode is off before using the exploit.** Upon booting up the game normally, if a prompt appears alongside the Nintendo logo, select No. Do not hold B while booting up the game with the exploit. If the 60Hz mode prompt loads during the exploit, the game will crash.


If the memory card is inserted while the console is turned off, this save takes over after the Dolby logo and loads `boot.dol` from the memory card. Inserting the memory card while the console is on will let it function as a normal (empty) save, however saving any file or the options will erase the exploit.

This save relies on [FIX94](https://github.com/FIX94)’s [GC exploit DOL loader](https://github.com/FIX94/gc-exploit-common-loader/).

----

Super Mario Sunshine saves don’t contain any strings or variable-size fields, which cuts out a bunch of obvious exploits. The coin scores for each stage seemed to have some potential, as the game always tries to display them on 3 digits, meaning a big enough score might have it look up textures for digits far beyond 9. This would be similar to how Gen I Pokémon games display garbage tiles for item quantities over 99, except with more complex objects that could let us gain control. Unfortunately, the coin scores are properly capped between 0 and 999, making this exploit impossible.

Enter the PAL language option. Interestingly, when getting the system language, the game correctly checks that it’s between 0 and 4, as Dutch (5) is unsupported. However, when the language is read from the memory card, it is assumed to be one of the 5 supported languages, and used as is.

The game relies on static arrays to get the right string for a given language, and the language flag is used as an index in those arrays. So the goal is to get something to be read from the memory card buffer, spanning from `0x8073D240` to `0x8073F240`. The first thing I could control were the DVD error messages, as those are hard-coded in the DOL rather than loaded from separate files, but that doesn’t lead into much more than [showing a funny message when the disc lid is open](https://twitter.com/Qbe_Root/status/1177969275220480000).

Next up is the 60Hz prompt. This time the game is looking for a file name and doesn’t copy it anywhere while looking up the file, meaning we would have to supply a file that is already on the disc and hope it happens to redirect execution into something we can control. Maybe it’s possible, but for now let’s just disable the prompt to make sure it doesn’t get in the way.

Then comes a function called `load2DResource2Aram`, which looks up 3 separate filenames. And this time, each of them is getting copied onto the stack, with `strcpy` no less! Unfortunately, this function uses the language flag as a single byte, and since the array closest to the memory card buffer starts at `0x803D6C20`, there’s no way we could make it. On the other hand, the clamping means that this function won’t cause trouble as long as the least significant byte of the language flag is between 0 and 4, so we can move on.

The magic happens as the game tries to load subtitles for the intro cutscene: it looks up yet another filename with the unclamped language flag, and sends it to `SMSLoadArchive` which `strcpy`s it onto the stack! So now it’s time for some math. The array starts at `0x803D7390` and we need to land between `0x8073D240` to `0x8073F240`, so the offset needs to be between `0x365EB0` and `367EB0`. Each element in the array is a 4-byte pointer to the corresponding string, so we need the language flag to be between `0xD97AC` and `0xD9FAC`. I picked `0xD9E00` as it lands in an area that normal save files don’t use at all, and ends with a 0 byte for `load2DResource2Aram`.

*Note: the language flag stored in the save file is actually `0xD9E01`, because the game shifts the save file language by 1 so that 0 can always be treated as “unspecified” and overridden with the system language.*

So, once the game tries to load the subtitles, the corrupted language flag causes it to read a string pointer from `0x8073EB90`, which is offset `0x1950` within the save file buffer. That pointer points to `0x8073EB90`: its own address, because none of the 4 bytes that make up the address are null, so they’re fine to use in the padding string. The padding string is 96 bytes long, doesn’t contain any null bytes and is immediately followed by the address of the payload (`0x8073EBF8` -- `0x19B8` within the save file buffer), so that `strcpy` will copy said address right over the return address of `SMSLoadArchive`. The function terminates somewhat normally (though nothing gets loaded because the file was surprisingly not found), jumps to its return address, and we now get to run any code we want within the limits of the memory card.

This was my first time writing an exploit like this so I didn’t really know how to turn it into a way to run homebrew, massive thanks to FIX94 for [his blog post on how he did exactly that for multiple different games](https://gbatemp.net/entry/gamecube-save-exploits-the-common-loader.15057/)!