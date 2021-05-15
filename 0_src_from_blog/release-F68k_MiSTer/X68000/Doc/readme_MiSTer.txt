FPGA版X68k互換機readme:
本RTLはDE10-nano(TERASIC社)上で動作するMiSTerにて
X68000相当の機能を持たせる物です。

FPGA version X68k compatible machine readme:
This RTL is a MiSTer running on DE10-nano (TERASIC)
It is a thing that has a function equivalent to X68000.

本RTLに関しては、フリーソフトウェアです。
・MC68000 MPUのIP : TG68はTobias Gubenerさんに著作権があります。

This RTL is free software.
・MC68000 MPU IP: TG68 is copyrighted by Tobias Gubener.


その他のRTLに関しては私、プーにあります。
このRTLに含まれるファイルに関しては一切無保証です。2次的被害を含む一切の責任は
負いません。

For other RTL, I'm at Puu.
There is no warranty for the files included in this RTL. No liability for secondary damage
I will not bear it.

動作異常等に関しては、ブログ
http://fpga8801.seesaa.net/
内のメッセージやコメントにて連絡をお願いいたします。

About abnormal operation etc., blog
http://fpga8801.seesaa.net/
Please contact us with the message or comment inside.


使用方法:
本RTLはAltera社の開発環境 QuartusII web editionにて主に開発されており、
本配布もQuartusIIのarchive機能にてパッケージ化されております。
本RTLをProject→Restore archived projectにて展開を行い
(このファイルが開けている時点で完了していると思いますが)
Start Compilationにてコンパイルを行ってください。
.rbfファイルと.sofファイルが生成されます。.sofファイルはJTAGモードにて書き込みで使用します。
.rbfファイルはMiSTerに準拠するようにファイル名を「X68000_YYYYMMDD.rbf」に修正し、MiSTerのSDカードルートディレクトリに
コピーしてください。(YYYYMMDDは本日の日付)
BIOSイメージはSDカードからロードします。
CGROMとIPLROMを、この順番でマージしたものを/X68000/boot.romとしてMiSTer用SDカードに保存してください。

how to use:
This RTL is mainly developed in the QuartusII web edition development environment of Altera,
and this distribution is also packaged with the archive function of QuartusII.
Extract this RTL by Project → Restore archived project (I think it is completed when this file is open)
and compile by Start Compilation.
A .rbf file and a .sof file are generated. The .sof file is used for writing in JTAG mode.
Correct the filename of the .rbf file to "X68000_YYYYMMDD.rbf" so that it conforms to MiSTer,
and copy it to the SD card root directory of MiSTer. (YYYYMMDD is today's date)
The BIOS image loads from the SD card.
Please save the merged CGROM and IPLROM in this order as /X68000/boot.rom to the SD card for MiSTer.

CGROMは実機のものは公開されておりません。また、EX68でWindowsのフォントから
変換したものもライセンス上、公開できませんので、アーカイブに含まれているものは
Linux(X11)上のWineでEX68を動作させ、生成させたものを同梱しています。

The actual CGROM is not available. Also, with EX68 from Windows fonts
The converted version cannot be published due to the license, so what is included in the archive is
We have created a package that was created by running EX68 on Wine on Linux (X11).

F12でMiSTerのメニュー(OSD)に切り替わり、ディスクエミュレータ等の設定が可能です。
ディスクイメージはMiSTerSDカードのX68000ディレクトリに保存してください。
HDDはSASIですので40MBまでのイメージに対応、拡張子は.HDFです。FDDはD88フォーマットです。
Virtual Floppy Image Converterを用いてXDF→D88変換し、正常に動作することを確認しました。
SRAMの内容はファイルからの読み込み・保存が可能です。拡張子は.RAMです。
自動での読み込み・保存は行われませんのでMiSTerメニューから、ファイルからSRAMへのコピーは「LOAD SRAM」を、
SRAMからファイルへのコピーは「STORE SRAM」を選択してください。

You can switch to the MiSTer menu (OSD) with F12 and set the disk emulator etc.
Save the disk image to the X68000 directory on the MiSTer SD card.
The HDD is SASI, so it supports images up to 40MB and the extension is .HDF. FDD is D88 format.
I converted XDF to D88 using Virtual Floppy Image Converter and confirmed that it works properly.
The contents of SRAM can be read and saved from a file. The extension is .RAM.
Since it is not automatically loaded/saved, from the MiSTer menu, copy "LOAD SRAM" from the file to SRAM.
Select "STORE SRAM" to copy from SRAM to a file.

FDDへの読書きはSDRAMを介して行われます。FDDへの書き込みは一度SDRAMに書き込まれた後、一定時間(3秒間)後に
自動でファイルに書き戻される設定になっています。また、SYNC,EJECTを選択した時にも書き戻しを行いますが
ファイル選択画面で[BS]を押してマウント解除した場合は書き戻しが出来ませんので注意してください。

Reading and writing to FDD is done via SDRAM. The writing to FDD is set to be automatically written back 
to the file after being written to SDRAM once and after a fixed time (3 seconds). Also, if you select SYNC or 
EJECT, the data will be written back, but if you unmount the file by pressing [BS] on the file selection screen,
you cannot write it back.
