# P17 report: verified reference list

Checked 2026-11-20. Every DOI below was resolved with the Crossref REST API
(`https://api.crossref.org/works/<DOI>`), or with DataCite for the two DataCite DOIs.
Title, authors, venue, volume, issue, pages and year were compared field by field.
Each entry is IEEE style and ready to paste into `thebibliography`. The `Verified:` line
under each entry says what was checked and where. Where something could not be checked,
the line says so.

Abbreviations: "Crossref match" = title, authors, venue, vol/no/pages and year in the
Crossref record agree with the entry; "full text read" = the numbers used in
`comparison.md` were read from the paper itself; "abstract only" = only the abstract was read.

---

## A. Chosen paper and software QRS detectors

```latex
\bibitem{pan1985} J.~Pan and W.~J. Tompkins, ``A real-time {QRS} detection algorithm,'' \emph{IEEE Trans. Biomed. Eng.}, vol. BME-32, no.~3, pp. 230--236, Mar. 1985, doi: 10.1109/TBME.1985.325532.
```
Verified: Crossref match (vol. BME-32, no. 3, pp. 230-236, Mar. 1985). PubMed PMID 3997178. I read the full paper from a scanned copy (Cornell ECE 5030 course mirror). That covers the abstract, the filter equations, the threshold rules and Table I.

```latex
\bibitem{hamilton1986} P.~S. Hamilton and W.~J. Tompkins, ``Quantitative investigation of {QRS} detection rules using the {MIT/BIH} arrhythmia database,'' \emph{IEEE Trans. Biomed. Eng.}, vol. BME-33, no.~12, pp. 1157--1165, Dec. 1986, doi: 10.1109/TBME.1986.325695.
```
Verified: Crossref match. PubMed PMID 3817849. I read the abstract through the OpenAlex API. The full text is paywalled and was not read.

```latex
\bibitem{elgendi2013} M.~Elgendi, ``Fast {QRS} detection with an optimized knowledge-based method: Evaluation on 11 standard {ECG} databases,'' \emph{PLoS ONE}, vol.~8, no.~9, Art. no. e73557, Sep. 2013, doi: 10.1371/journal.pone.0073557.
```
Verified: Crossref match (vol. 8, no. 9, e73557, published online 16 Sep 2013). Full text read (open access, PMC3774726 via Europe PMC).

```latex
\bibitem{martinez2004} J.~P. Mart\'{\i}nez, R.~Almeida, S.~Olmos, A.~P. Rocha, and P.~Laguna, ``A wavelet-based {ECG} delineator: Evaluation on standard databases,'' \emph{IEEE Trans. Biomed. Eng.}, vol.~51, no.~4, pp. 570--581, Apr. 2004, doi: 10.1109/TBME.2003.821031.
```
Verified: Crossref match. Abstract read on PubMed (PMID 15072211). Full text is paywalled and was not read. The MIT-BIH beat counts are taken from two later papers that tabulate them (see comparison.md).

```latex
\bibitem{li1995} C.~Li, C.~Zheng, and C.~Tai, ``Detection of {ECG} characteristic points using wavelet transforms,'' \emph{IEEE Trans. Biomed. Eng.}, vol.~42, no.~1, pp. 21--28, Jan. 1995, doi: 10.1109/10.362922.
```
Verified: Crossref match. Abstract read on PubMed (PMID 7851927). Full text not read.

```latex
\bibitem{arzeno2008} N.~M. Arzeno, Z.-D. Deng, and C.-S. Poon, ``Analysis of first-derivative based {QRS} detection algorithms,'' \emph{IEEE Trans. Biomed. Eng.}, vol.~55, no.~2, pp. 478--484, Feb. 2008, doi: 10.1109/TBME.2007.912658.
```
Verified: Crossref match. Abstract read on PubMed (PMID 18269982). The table values came from the PMC author manuscript (PMC2532677) through a page-fetch summariser. I re-checked them arithmetically (TP/FP/FN reproduce the printed Se and +P exactly).

```latex
\bibitem{dimarco2011} L.~Y. Di~Marco and L.~Chiari, ``A wavelet-based {ECG} delineation algorithm for 32-bit integer online processing,'' \emph{BioMed. Eng. OnLine}, vol.~10, Art. no.~23, 2011, doi: 10.1186/1475-925X-10-23.
```
Verified: Crossref match (vol. 10, art. 23, 2011). Full text read (open access, PMC3076264).

---

## B. Hardware (FPGA / ASIC) QRS detectors

```latex
\bibitem{cvikl2007} M.~Cvikl, F.~Jager, and A.~\v{Z}emva, ``Hardware implementation of a modified delay-coordinate mapping-based {QRS} complex detection algorithm,'' \emph{EURASIP J. Adv. Signal Process.}, vol.~2007, Art. no.~57286, 2007, doi: 10.1155/2007/57286.
```
Verified: Crossref match (vol. 2007, published Dec. 2007). Full text read (open access PDF, 13 pages). The PDF header reads "Volume 2007, Article ID 57286, 13 pages".

```latex
\bibitem{stojanovic2011} R.~Stojanovi\'{c}, D.~Karadagli\'{c}, M.~Mirkovi\'{c}, and D.~Milo\v{s}evi\'{c}, ``A {FPGA} system for {QRS} complex detection based on integer wavelet transform,'' \emph{Meas. Sci. Rev.}, vol.~11, no.~4, pp. 131--138, 2011, doi: 10.2478/v10048-011-0024-z.
```
Verified: Crossref match for title, authors, vol. 11, no. 4 and 2011. Crossref has no page numbers. Pages 131-138 come from DOAJ and from the page header of the PDF, which I read in full (open access).

```latex
\bibitem{chen2020} A.~Chen, Y.~Zhang, M.~Zhang, W.~Liu, S.~Chang, H.~Wang, J.~He, and Q.~Huang, ``A real time {QRS} detection algorithm based on {ET} and {PD} controlled threshold strategy,'' \emph{Sensors}, vol.~20, no.~14, Art. no.~4003, Jul. 2020, doi: 10.3390/s20144003.
```
Verified: Crossref match. Full text read (open access, PMC7412314).

```latex
\bibitem{madiraju2018} N.~S. Madiraju, N.~Kurella, and R.~Valapudasu, ``{FPGA} implementation of {ECG} feature extraction using time domain analysis,'' arXiv:1802.03310, 2018, doi: 10.48550/arXiv.1802.03310.
```
Verified: DataCite record (arXiv DOI). Full text read (4-page PDF). This is a preprint and was not peer reviewed. The third author's surname is spelled "Valapudasu" in both DataCite and the PDF, so that spelling is kept.

```latex
\bibitem{huang2012} S.-C. Huang, H.-M. Wang, and W.-Y. Chen, ``A $\pm$6\,ms-accuracy, 0.68\,mm$^2$, and 2.21\,$\mu$W {QRS} detection {ASIC},'' \emph{VLSI Design}, vol.~2012, Art. no.~809393, 2012, doi: 10.1155/2012/809393.
```
Verified: Crossref match for title, authors, journal, vol. 2012 and year. Abstract only, read through OpenAlex. The full-text PDF host showed a bot-check page, which I did not try to get past. The article number follows the Hindawi convention (equal to the DOI suffix) but was not seen on the article itself.

```latex
\bibitem{ieong2012} C.-I. Ieong, P.-I. Mak, C.-P. Lam, C.~Dong, M.-I. Vai, P.-U. Mak, S.-H. Pun, F.~Wan, and R.~P. Martins, ``A 0.83-$\mu$W {QRS} detection processor using quadratic spline wavelet transform for wireless {ECG} acquisition in 0.35-$\mu$m {CMOS},'' \emph{IEEE Trans. Biomed. Circuits Syst.}, vol.~6, no.~6, pp. 586--595, Dec. 2012, doi: 10.1109/TBCAS.2012.2188798.
```
Verified: Crossref match. Abstract only (OpenAlex).

```latex
\bibitem{meddah2019} K.~Meddah, M.~Kedir~Talha, M.~Bahoura, and H.~Zairi, ``{FPGA}-based system for heart rate monitoring,'' \emph{IET Circuits Devices Syst.}, vol.~13, no.~6, pp. 771--782, Sep. 2019, doi: 10.1049/iet-cds.2018.5204.
```
Verified: Crossref match. Abstract only. The paper is closed access and its abstract gives no resource or accuracy numbers, so none are used.

```latex
\bibitem{meddah2020} K.~Meddah, M.~Kedir~Talha, H.~Zairi, M.~Nouah, S.~Hadji, M.~A. Ait, B.~Bessekri, and H.~Cherrih, ``{FPGA} implementation system for {QRS} complex detection,'' \emph{Biomed. Eng. Appl. Basis Commun.}, vol.~32, no.~1, Art. no.~2050005, Feb. 2020, doi: 10.4015/S1016237220500052.
```
Verified: Crossref match. Abstract only.

```latex
\bibitem{kovacevic2014} J.~Kova\v{c}evi\'{c}, R.~Stojanovi\'{c}, D.~Karadagli\'{c}, B.~A\v{s}anin, Z.~Kova\v{c}evi\'{c}, Z.~Bundalo, and F.~Softi\'{c}, ``{FPGA} low-power implementation of {QRS} detectors,'' in \emph{Proc. 3rd Mediterranean Conf. Embedded Comput. (MECO)}, Jun. 2014, pp. 98--101, doi: 10.1109/MECO.2014.6862667.
```
Verified: Crossref match. Abstract only. The conference city was not checked and is left out on purpose.

---

## C. Pacemaker modelling and verification

```latex
\bibitem{jiang2012tacas} Z.~Jiang, M.~Pajic, S.~Moarref, R.~Alur, and R.~Mangharam, ``Modeling and verification of a dual chamber implantable pacemaker,'' in \emph{Tools and Algorithms for the Construction and Analysis of Systems (TACAS 2012)}, C.~Flanagan and B.~K\"{o}nig, Eds., Lecture Notes in Computer Science, vol.~7214. Berlin, Germany: Springer, 2012, pp. 188--203, doi: 10.1007/978-3-642-28756-5_14.
```
Verified: Crossref match (chapter pp. 188-203; editors from the Crossref book record). I read the full chapter PDF (free on SpringerLink). The first-page footer reads "TACAS 2012, LNCS 7214, pp. 188-203, 2012".

```latex
\bibitem{jiang2012procieee} Z.~Jiang, M.~Pajic, and R.~Mangharam, ``Cyber--physical modeling of implantable cardiac medical devices,'' \emph{Proc. IEEE}, vol.~100, no.~1, pp. 122--137, Jan. 2012, doi: 10.1109/JPROC.2011.2161241.
```
Verified: Crossref match (print issue Jan. 2012; some indexes give 2011, the online date). Abstract only (OpenAlex).

```latex
\bibitem{bsc2007} Boston Scientific, ``{PACEMAKER} system specification,'' Jan. 3, 2007. [Online]. Available: https://sqrl.cas.mcmaster.ca/_SQRLDocuments/PACEMAKER.pdf
```
Verified: no DOI. I read the 35-page PDF from the Internet Archive snapshot (13 Aug 2025) of the SQRL URL above. Its title page reads "PACEMAKER System Specification, Copyright 2007 Boston Scientific, January 3, 2007", with a disclaimer that it is for academic use only. The live McMaster SQRL server did not respond from this machine, so the URL was confirmed only through the archive and web search. The TACAS 2012 paper cites this document as "PACEMAKER System Specification. Boston Scientific (2007)".

```latex
\bibitem{macedo2008} H.~D. Macedo, P.~G. Larsen, and J.~Fitzgerald, ``Incremental development of a distributed real-time model of a cardiac pacing system using {VDM},'' in \emph{FM 2008: Formal Methods}, J.~Cuellar, T.~Maibaum, and K.~Sere, Eds., Lecture Notes in Computer Science, vol.~5014. Berlin, Germany: Springer, 2008, pp. 181--197, doi: 10.1007/978-3-540-68237-0_14.
```
Verified: Crossref match (chapter pp. 181-197; book editors from Crossref). LNCS volume 5014 comes from the Open Library record for ISBN 9783540682356 and from the TACAS 2012 reference list. Abstract read from the Newcastle University repository record (DataCite 10.25405/ncl.34130151). Full text not read.

---

## D. Background references

```latex
\bibitem{moody2001} G.~B. Moody and R.~G. Mark, ``The impact of the {MIT-BIH} arrhythmia database,'' \emph{IEEE Eng. Med. Biol. Mag.}, vol.~20, no.~3, pp. 45--50, May--Jun. 2001, doi: 10.1109/51.932724.
```
Verified: Crossref match. The month (May-Jun) is from PubMed (PMID 11446209).

```latex
\bibitem{goldberger2000} A.~L. Goldberger, L.~A.~N. Amaral, L.~Glass, J.~M. Hausdorff, P.~Ch. Ivanov, R.~G. Mark, J.~E. Mietus, G.~B. Moody, C.-K. Peng, and H.~E. Stanley, ``{PhysioBank}, {PhysioToolkit}, and {PhysioNet}: Components of a new research resource for complex physiologic signals,'' \emph{Circulation}, vol.~101, no.~23, pp. e215--e220, Jun. 2000, doi: 10.1161/01.CIR.101.23.e215.
```
Verified: Crossref match for authors, journal, vol. 101, no. 23 and 13 Jun 2000. Crossref holds only the short title and no pages. The full title and pages "E215-20" come from PubMed (PMID 10851218).

```latex
\bibitem{mitdb} G.~B. Moody and R.~G. Mark, ``{MIT-BIH} arrhythmia database (version 1.0.0),'' PhysioNet, 2005, doi: 10.13026/C2F305.
```
Verified: DataCite record (creators Moody, Mark; publisher PhysioNet; year 2005; URL physionet.org/content/mitdb/1.0.0/). This entry is optional. PhysioNet asks users to cite moody2001 and goldberger2000 as well.

```latex
\bibitem{aamiec57} \emph{Testing and Reporting Performance Results of Cardiac Rhythm and {ST} Segment Measurement Algorithms}, ANSI/AAMI EC57:2012/(R)2020, Association for the Advancement of Medical Instrumentation, 2012 (reaffirmed 2020).
```
Verified: no DOI. The designation "ANSI/AAMI EC57:2012/(R)2020" was read on the BSI Knowledge catalogue page, which also gives a publication date of 18 Mar 2013. The title is from the same BSI listing and the ANSI webstore listing (search result). The standard itself is paywalled and was not read. The earlier edition, ANSI/AAMI EC57:1998, is the one Di Marco & Chiari 2011 cite for the 150 ms QRS-matching tolerance. If you cite the 150 ms figure, you can attribute it to the standard "as cited in [dimarco2011]".

```latex
\bibitem{bernstein2002} A.~D. Bernstein, J.-C. Daubert, R.~D. Fletcher, D.~L. Hayes, B.~L\"{u}deritz, D.~W. Reynolds, M.~H. Schoenfeld, and R.~Sutton, ``The revised {NASPE/BPEG} generic code for antibradycardia, adaptive-rate, and multisite pacing,'' \emph{Pacing Clin. Electrophysiol.}, vol.~25, no.~2, pp. 260--264, Feb. 2002, doi: 10.1046/j.1460-9592.2002.00260.x.
```
Verified: Crossref match. Abstract read on PubMed (PMID 11916002). The abstract confirms the meaning of positions IV and V. Positions I-III (paced chamber, sensed chamber, response to sensing) were confirmed from Table 2 of the Boston Scientific specification [bsc2007]. The PACE paper's own table was not read.

```latex
\bibitem{cimatti2002} A.~Cimatti, E.~Clarke, E.~Giunchiglia, F.~Giunchiglia, M.~Pistore, M.~Roveri, R.~Sebastiani, and A.~Tacchella, ``{NuSMV} 2: An {OpenSource} tool for symbolic model checking,'' in \emph{Computer Aided Verification (CAV 2002)}, E.~Brinksma and K.~G. Larsen, Eds., Lecture Notes in Computer Science, vol.~2404. Berlin, Germany: Springer, 2002, pp. 359--364, doi: 10.1007/3-540-45657-0_29.
```
Verified: Crossref match (chapter pp. 359-364; editors from the Crossref book record). The Crossref record has no series number. LNCS vol. 2404 was confirmed from the SpringerLink citation and the University of Trento repository record, both seen through web search.

```latex
\bibitem{bryant1986} R.~E. Bryant, ``Graph-based algorithms for {Boolean} function manipulation,'' \emph{IEEE Trans. Comput.}, vol.~C-35, no.~8, pp. 677--691, Aug. 1986, doi: 10.1109/TC.1986.1676819.
```
Verified: Crossref match for title, venue, vol./no./pages and Aug. 1986. Crossref stores the author as the surname "Bryant" only. The initials "R. E." (Randal E. Bryant) are the standard attribution but are not in the Crossref record.

```latex
\bibitem{rudell1993} R.~Rudell, ``Dynamic variable ordering for ordered binary decision diagrams,'' in \emph{Proc. IEEE/ACM Int. Conf. Comput.-Aided Des. (ICCAD)}, Santa Clara, CA, USA, Nov. 1993, pp. 42--47, doi: 10.1109/ICCAD.1993.580029.
```
Verified: Crossref match for title, author, pp. 42-47, event "1993 International Conference on Computer Aided Design (ICCAD)" and location Santa Clara, CA. Crossref has no issue date. The year comes from the event name. The month "Nov." is not in Crossref, so remove it if you want only checked fields.

```latex
\bibitem{clarke1986} E.~M. Clarke, E.~A. Emerson, and A.~P. Sistla, ``Automatic verification of finite-state concurrent systems using temporal logic specifications,'' \emph{ACM Trans. Program. Lang. Syst.}, vol.~8, no.~2, pp. 244--263, Apr. 1986, doi: 10.1145/5397.5399.
```
Verified: Crossref match.

```latex
\bibitem{brayton1984} R.~K. Brayton, G.~D. Hachtel, C.~T. McMullen, and A.~L. Sangiovanni-Vincentelli, \emph{Logic Minimization Algorithms for {VLSI} Synthesis}, ser. The Kluwer International Series in Engineering and Computer Science. Kluwer Academic Publishers, 1984, doi: 10.1007/978-1-4613-2821-6.
```
Verified: Crossref match. This is a book record: authors, series, 1984, and publisher now listed as "Springer US". Unusually for a book, it has a DOI. The publisher city was not checked and is left out.

```latex
\bibitem{sentovich1992} E.~M. Sentovich, K.~J. Singh, L.~Lavagno, C.~Moon, R.~Murgai, A.~Saldanha, H.~Savoj, P.~R. Stephan, R.~K. Brayton, and A.~L. Sangiovanni-Vincentelli, ``{SIS}: A system for sequential circuit synthesis,'' Electronics Research Laboratory, Univ. of California, Berkeley, CA, USA, Tech. Rep. UCB/ERL M92/41, May 1992. [Online]. Available: https://www2.eecs.berkeley.edu/Pubs/TechRpts/1992/2010.html
```
Verified: no DOI. Authors, title, report number UCB/ERL M92/41 and "May 1992" were read on the UC Berkeley EECS technical-report page. The PDF is at .../1992/Archive/ERL-92-41.pdf (HTTP 200).

```latex
\bibitem{demicheli1994} G.~De~Micheli, \emph{Synthesis and Optimization of Digital Circuits}. New York, NY, USA: McGraw-Hill, 1994.
```
Verified: no DOI. Open Library record for ISBN 0-07-016333-2: McGraw-Hill, New York, 1994, 579 pp., McGraw-Hill Series in Electrical and Computer Engineering.

```latex
\bibitem{paulin1989} P.~G. Paulin and J.~P. Knight, ``Force-directed scheduling for the behavioral synthesis of {ASICs},'' \emph{IEEE Trans. Comput.-Aided Des. Integr. Circuits Syst.}, vol.~8, no.~6, pp. 661--679, Jun. 1989, doi: 10.1109/43.31522.
```
Verified: Crossref match.

```latex
\bibitem{kurdahi1987} F.~J. Kurdahi and A.~C. Parker, ``{REAL}: A program for {REgister ALlocation},'' in \emph{Proc. 24th ACM/IEEE Design Automation Conf. (DAC)}, 1987, pp. 210--215, doi: 10.1145/37888.37920.
```
Verified: Crossref match (DAC '87, pp. 210-215). Note: DOI 10.1145/37888.37918 belongs to a different paper, Paulin & Knight's DAC '87 "Force-directed scheduling in automatic data path synthesis". Do not mix the two up.

```latex
\bibitem{neorv32} S.~Nolting, ``The {NEORV32} {RISC-V} processor,'' GitHub repository, 2020--2026. [Online]. Available: https://github.com/stnolting/neorv32
```
Verified: no DOI. Checked through the GitHub API and repo files: owner `stnolting`, README title "The NEORV32 RISC-V Processor", LICENSE "Copyright (c) 2020-2026, Stephan Nolting" (BSD-3-Clause), repo created 2020-06-23. The online datasheet is at https://stnolting.github.io/neorv32/ (HTTP 200). Add an access date in the report, e.g. "Accessed: Nov. 2026".

```latex
\bibitem{yosys} C.~Wolf, ``Yosys Open SYnthesis Suite.'' [Online]. Available: https://yosyshq.net/yosys/
```
Verified: no DOI. Both https://yosyshq.net/yosys/ and https://github.com/YosysHQ/yosys return HTTP 200. The GitHub description is "Yosys Open SYnthesis Suite". The COPYING file names "Claire Xenia Wolf" as copyright holder (2012-2026).

```latex
\bibitem{sby} YosysHQ, ``{SBY} ({SymbiYosys}): Front-end for {Yosys}-based formal verification flows.'' [Online]. Available: https://github.com/YosysHQ/sby
```
Verified: no DOI. The GitHub API description reads "SBY -- Front-end for Yosys-based formal verification flows" (repo created 2017). Documentation is at https://symbiyosys.readthedocs.io/ (HTTP 200).

```latex
\bibitem{ug1399} AMD (Xilinx), \emph{Vitis High-Level Synthesis User Guide}, UG1399 (v2025.2). [Online]. Available: https://docs.amd.com/r/2025.2-English/ug1399-vitis-hls
```
Verified: no DOI. The docs.amd.com page gives the title "Vitis High-Level Synthesis User Guide", document number UG1399. The newest listed version is 2026.2 (11 Nov 2026). The 2025.2 URL resolves (HTTP 200) and matches the Vivado/Vitis 2025.2 tools used in the project. The release date of v2025.2 was not checked.

```latex
\bibitem{zybo} Digilent Inc., \emph{Zybo Z7 Board Reference Manual}, rev.~B, Feb. 2018. [Online]. Available: https://digilent.com/reference/programmable-logic/zybo-z7/reference-manual
```
Verified: no DOI. I read the PDF (a university mirror copy of `zybo-z7_rm.pdf`). It says "Zybo Z7 Board Reference Manual, Revised February 21, 2018, ... rev. B" and lists Zybo Z7-10 = XC7Z010-1CLG400C, 17,600 LUTs, 35,200 flip-flops, 270 KB block RAM. digilent.com returned HTTP 403 to automated requests, so the live URL above was not opened. Web search lists it as the official page.

---

### What could not be fully verified

- Hamilton & Tompkins 1986: I read the abstract (Se 99.69 %, +P 99.77 %) but not the full text. The beat count (109,267) and FP/FN (248/340) come from Di Marco & Chiari 2011 Table 4 (secondary). The matching tolerance and any records left out are unknown.
- Martínez 2004: I read the abstract (MIT-BIH Se and +P "over 99.8 %"). The exact 99.80/99.86 %, 109,428 beats and the record-207 exclusion come from Di Marco 2011 and Elgendi 2013 (secondary). The tolerance is unknown.
- Li 1995: I read the abstract only. The beat count and the exclusion of records 214/215 are secondary (Di Marco 2011, Elgendi 2013).
- Huang 2012 ASIC and Ieong 2012 ASIC: abstract only. Clock, gate count and evaluation protocol not seen.
- Meddah 2019 and 2020, Kovačević 2014: abstract only. No resource numbers are available from the abstracts.
- ANSI/AAMI EC57: I confirmed the edition designation and title from catalogue listings. The standard itself and its 150 ms rule were not read; the 150 ms rule is cited second-hand from Di Marco 2011.
- Minor fields from general knowledge, not from a checked record: Bryant's initials (R. E.); Rudell's month (Nov. 1993). Each is flagged on its entry.
