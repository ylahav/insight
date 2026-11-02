# What can be learned

Two profile recordings of one script. `play --board bloc` wrote `examples/exchange/1.json`. `play --board riverpod` wrote `examples/exchange/2.json`. Both played [answered-call.txt](../examples/exchange/scenarios/answered-call.txt): phone 1 goes off hook, dials 2, and phone 2 answers. `compare` wrote `examples/exchange/compare.json`.

The columns in that file stay `left` and `right`. That is the order of `--left` and `--right`. Each column stores `board`. The sentences use that name. This pair says `bloc` and `riverpod`.

Both files are profile. Both scripts match. The stored commit is `feb8b4a` on `main`, and the scenario file was clean. The runs started about twenty seconds apart on 2 November 2026.

Choosing three lines and opening the board did not add a compared state row. Three steps did.

**Step 1** is `tap phone-1`. The state row is `ExchangeCubit → Exchange` on bloc and `exchange → Exchange` on riverpod. Both rebuilt `ExchangeHost`, `ExchangeActions`, `ExchangeScope`, `LinePhone`, `_Lamp`, and four `DialKey`s. Bloc also rebuilt `_InheritedProviderScope<ExchangeCubit?>`.

**Step 2** is `tap digit-1-2`. The shared names are `ExchangeHost`, `ExchangeActions`, `ExchangeScope`, `SwitchDesk`, `CustomPaint`, two `LinePhone`s, and two `_Lamp`s. The extra name is the same Bloc scope.

**Step 3** is `tap phone-2`. The names match step 2.

Build is longer on riverpod in steps 1, 2, and 3 (bloc 1.4 ms, riverpod 1.5 ms; bloc 1.0 ms, riverpod 1.1 ms; bloc 1.1 ms, riverpod 1.3 ms).

Raster is longer on bloc in step 3 (bloc 0.5 ms, riverpod 0.4 ms), and longer on riverpod in steps 1 and 2 (bloc 0.6 ms, riverpod 0.7 ms; bloc 0.9 ms, riverpod 1.0 ms).

Elapsed is longer on bloc in step 2 (bloc 4.1 ms, riverpod 2.7 ms), and longer on riverpod in steps 1 and 3 (bloc 3.1 ms, riverpod 3.3 ms; bloc 2.4 ms, riverpod 2.9 ms).

Each step rebuilt 10 widgets on bloc and 9 on riverpod. The extra widget is the Bloc scope. The bloc elapsed time is shorter in steps 1 and 3, and longer in step 2. The extra widget and the longer frame do not stay on the same side. That is the count beside the time. It is not a cause.

These tenths are one run of each board. Another run can print different ones. The reading is which side was longer in these files. It is not a pass or a fail.

How to record the pair again is in [running-example.md](running-example.md). The next recording keeps Bloc and changes the board, as [roadmap.md](roadmap.md) describes.

## The wide board

Two more profile recordings of one script. `play --board wide` wrote `examples/exchange/1.json`. `play --board bloc` wrote `examples/exchange/2.json`. Both played [third-phone.txt](../examples/exchange/scenarios/third-phone.txt). Three lines. Phone 1 goes off hook and dials 2. The script stops when the screen says `Calling 2` and `2 is ringing`. Phone 2 does not answer. Phone 3 is never in the call.

Both boards are the enamel phones, and both state rows are `ExchangeCubit → Exchange`. Wide is the same Bloc switch with every phone reading the whole exchange. The enamel board leaves that off: each phone reads its own line. The words on screen match. The widget list is the difference.

Both files are profile. Both scripts match. The stored commit is `feb8b4a` on `main`, and the scenario file was dirty. The enamel run started at 11:24 and the wide run at 11:35, on 2 November 2026. Choosing three lines and opening the board did not add a compared state row. Two steps did.

**Step 1** is `tap phone-1`. Wide rebuilt three `LinePhone`s and three `_Lamp`s. The four `DialKey`s sit on the phone that went off hook. Bloc rebuilt one `LinePhone`, one `_Lamp`, and those four keys. Both rebuilt `_InheritedProviderScope<ExchangeCubit?>`, `ExchangeHost`, `ExchangeActions`, and `ExchangeScope`.

**Step 2** is `tap digit-1-2`. Both rebuilt `SwitchDesk` and `CustomPaint`. Wide rebuilt three `LinePhone`s and three `_Lamp`s. Bloc rebuilt two of each. The idle phone is on the wide row only.

Build is longer on bloc in steps 1 and 2 (wide 1.7 ms, bloc 2.3 ms; wide 1.2 ms, bloc 1.3 ms).

Raster is longer on bloc in steps 1 and 2 (wide 0.5 ms, bloc 1.8 ms; wide 0.7 ms, bloc 1.2 ms).

Elapsed is longer on wide in step 1 (wide 20.8 ms, bloc 9.1 ms), and the same in step 2 (2.7 ms).

Step 1 rebuilt 14 widgets on wide and 10 on bloc, and the wide elapsed time is longer. Step 2 rebuilt 12 widgets on wide and 10 on bloc, and the elapsed time matches. The extra names are the phones that are not in the action, and their lamps. On the dial step those extra widgets sit beside an elapsed time that matches. That is the count beside the time. It is not a cause.

These tenths are one run of each board. Another run can print different ones. The reading is which side was longer in these files. It is not a pass or a fail.
