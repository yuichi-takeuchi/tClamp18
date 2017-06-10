# tClamp18
tClamp18 offers a series of Igor Pro GUIs for data acquision via an InstruTECH ITC-18 AD/DA board. tClampt18 is optimized for whole-cell patch-clamp recordings in both voltage-clamp and current-clamp modes but it can be used for general data acquision purposes as well. tClamp18 also offers a quite flexible setting ablity harnessing 8 ADCs and 4 DACs with usefull template. Thus, it is an ideal solution for simultaneous multi-cellular whole-cell recordings with several patch-clamp amplifiers (Axon, HEKA, Werner, DAGAN, Nihon Kohden etc.).
a virtual 4 channel stimulator, internal timer, 

## Getting Started

### Prerequisites
* IGOR Pro 6 (https://www.wavemetrics.com/)
* InstruTECH ITC-18 and a host interface (http://www.heka.com/products/products_main.html#acq_itc18)
* Driver software of ITC-18 (http://www.heka.com/downloads/downloads_main.html#down_acq)
* ITC-18 legacy XOP for Igor Pro 6.x (ITC18_X86_V76.XOP) (http://www.heka.com/downloads/downloads_main.html#down_xops)

### Test
This code has been tested in Igor Pro version 6.3.7.2. for Windows and supposed to work in Igor Pro 6.1 or later.
This code is supposed to work for Windows Vista, 7, 8, 10 and Mac X also, but tested only in Windows XP and 7.
This code is supposed to work any host interfaces (PCI-18, PCI-18V3, or USB-18), but tested only with USB-18.

### Installing
#### Hardware
1. 

#### Software
1. Install Igor Pro 6.1 or later.
2. Put GlobalProcedure.ipf of tUtility or its shortcut into the Igor Procedures folder, which is normally located at My Documents\WaveMetrics\Igor Pro 6 User Files\Igor Procedures.
3. SetWindowExt.xop or its shortcut into the Igor Extensions folder, which is normally located at My Documents\WaveMetrics\Igor Pro 6 User Files\Igor Extensions.
4. Optional: SetWindowExt Help.ipf or its shortcut into the Igor Help Files folder, which is normally located at My Documents\WaveMetrics\Igor Pro 6 User Files\Igor Help Files.
5. Put tSort.ipf or its shortcut into the Igor Procedure folder.
6. Restart Igor Pro.

### How to initialize the tSort GUI
* Click "tSortInitialize" in "Initialize" submenu of "tSort" menu.
* Main control panel (tSortMainControlPanel), main graph (tSortMainGraph), event graph (tSortEventGraph), master table (tSortMasterTable), and slave table (tSortSlabeTable) windows will appear.

### How to use 
#### Setting of input and output gains with any amplifiers
* Click "tSortInitialize" in "Initialize" submenu of "tSort" menu.
* Main control panel (tSortMainControlPanel), main graph (tSortMainGraph), event graph (tSortEventGraph), master table (tSortMasterTable), and slave table (tSortSlabeTable) windows will appear.

#### Setting of oscilloscope (OSC) protocols: stimulus and recording settings


#### Spike detection and sorting
1. Get your waves into the List on "Main" tab of the main control panel using "GetAll" or "GetWL" buttons. The names of source waves on the list can directly be edited by cliking "EditList" button. Spike, LFP, ECoG, EMG, and Marker fields supporse to have high-pass filterd waves, low-pass filterd waves, LFP of another brain region, EMG, and TTL signal for stimulation. The list must have at least waves in the Spike field.
2. Set parameters for spike detection in "Extract" tab of the main control panel.
3. Set a source wave for analysis by clicking "srcWave" button on the Main tab of the main control panel.
4. Make the master table and the main graph ready for spike detection by clicking "MTablePrep" and then "DisplayInit" buttons on the Main tab.
5. Detect spikes on the source wave by clicking "AutoSearch" button on the Main tab.
6. Calculate several parameters associated with spikes (interevent intervals etc.) by clicking "EachParam" button on the Main tab.
7. Move on the next sweep (wave) by clicking "Next Sw" button on the panel of the main graph.
8. Repeat 5 to 7 over your all waves on the list.
9. Extract waveforms of all events by clicking "Extract" button of the event graph.
10. Do principle component analysis and get the first three figures for each spike by clicking "PCA" button on the Cluster tab of the main control panel.
11. Do clustering by clicking "FPC" button in Minimum group on the Cluster tab.
12. Calculate indexed interevent intervals and pattern index by clicking "IndexedIEI" and "PatternIndex" buttons on the master table.
13. Sort each unit whether burst or non-burst by clicking "BurstIndex" button on the panel of the main graph.

#### Analsysis of spontaneous firing
0. Set the analysis mode as Spontaneous by "Analysis Mode" pull-down menu on the Hist tab of the main control panel.
1. Make the slave table ready for the analysis by clicking "STablePrep" button on the Hist tab.
2. Specify source wave for analysis.
3. Display the source wave and then detect spikes on it by clicking "DisplayInit" and "AutoSearch" buttons on the Hist tab.
4. Repeat 2 to 3.
5. Sort each unit whether burst or non-burst by clicking "BurstIndex" button on the slave table.
6. Make raster waves by clicking "Raster" button on the Hist tab of the main control panel.
7. Make a summary of firing rate of each unit by clicking "Sponta Hz" button on the Hist tab.
8. Have firing rate histogram by cliking "Histogram" button on the Hist tab.

#### Anasysis of evoked firing (peri-stimulus time histogram)
0. Set the analyisis mode as PSTH by "Analysis Mode" pull-down menu on the Hist tab of the main control panel.
1. Make the slave table ready for the analysis by clicking "STablePrep" button on the Hist tab.
2. Set detection analytical parameters on the Hist tab (number of trials, time window width etc.).
3. Specify source wave for analysis.
4. Display the source wave and then detect spikes on it by clicking "DisplayInit" and "AutoSearch" buttons on the Hist tab.
5. Repeat 3 to 4.
6. Sort each unit whether burst or non-burst by clicking "BurstIndex" button on the slave table.
7. Make raster waves by clicking "Raster" button on the Hist tab of the main control panel.
8. Have firing rate histogram by cliking "Histogram" button on the Hist tab.

#### Save recordings
* 

### Help
* Click "Help" in "tSort" menu.

## DOI
[![DOI](https://zenodo.org/badge/93521987.svg)](https://zenodo.org/badge/latestdoi/93521987)

## Versioning
We use [SemVer](http://semver.org/) for versioning.

## Releases
* Version 1.0.0, 2017/06/10
* Prerelease, 2017/06/06

## Authors
* **Yuichi Takeuchi PhD** - *Initial work* - [GitHub](https://github.com/yuichi-takeuchi)
* Affiliation: Department of Physiology, University of Szeged, Hungary
* E-mail: yuichi-takeuchi@umin.net

## License
This project is licensed under the MIT License.

## Acknowledgments
* Department of Physiology, Tokyo Women's Medical University, Tokyo, Japan
* John Economides (http://www.igorexchange.com/project/GenSpikeSorting)

## References
tSort has been used for the following works:

* Takeuchi Y, Osaki H, Yagasaki Y, Katayama Y, Miyata M (2017) Afferent Fiber Remodeling in the Somatosensory Thalamus of Mice as a Neural Basis of Somatotopic Reorganization in the Brain and Ectopic Mechanical Hypersensitivity after Peripheral Sensory Nerve Injury. eNeuro 4:e0345-0316.
