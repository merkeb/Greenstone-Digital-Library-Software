#------------------------------------------------------------------------------
# File:         Canon.pm
#
# Description:  Canon EXIF maker notes tags
#
# Revisions:    11/25/2003 - P. Harvey Created
#               12/03/2003 - P. Harvey Decode lots more tags and add CanonAFInfo
#               02/17/2004 - Michael Rommel Added IxusAFPoint
#               01/27/2005 - P. Harvey Disable validation of CanonAFInfo
#               01/30/2005 - P. Harvey Added a few more tags (ref 4)
#               02/10/2006 - P. Harvey Decode a lot of new tags (ref 12)
#               [ongoing]  - P. Harvey Constantly decoding new information
#
# Notes:        Must check FocalPlaneX/YResolution values for each new model!
#
# References:   1) http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html
#               2) Michael Rommel private communication (Digital Ixus)
#               3) Daniel Pittman private communication (PowerShot S70)
#               4) http://www.wonderland.org/crw/
#               5) Juha Eskelinen private communication (20D)
#               6) Richard S. Smith private communication (20D)
#               7) Denny Priebe private communication (1DmkII)
#               8) Irwin Poche private communication
#               9) Michael Tiemann private communication (1DmkII)
#              10) Volker Gering private communication (1DmkII)
#              11) "cip" private communication
#              12) Rainer Honle private communication (5D)
#              13) http://www.cybercom.net/~dcoffin/dcraw/
#              14) (bozi) http://www.cpanforum.com/threads/2476 and /2563
#              15) http://homepage3.nifty.com/kamisaka/makernote/makernote_canon.htm (2007/11/19)
#                + http://homepage3.nifty.com/kamisaka/makernote/CanonLens.htm (2007/11/19)
#              16) Emil Sit private communication (30D)
#              17) http://www.asahi-net.or.jp/~xp8t-ymzk/s10exif.htm
#              18) Samson Tai private communication (G7)
#              19) Warren Stockton private communication
#              20) Bogdan private communication
#              21) Heiko Hinrichs private communication
#              22) Dave Nicholson private communication (PowerShot S30)
#              23) Magne Nilsen private communication (400D)
#              24) Wolfgang Hoffmann private communication (40D)
#              26) Steve Balcombe private communication
#              27) Chris Huebsch private communication (40D)
#              28) Hal Williamson private communication (XTi)
#              29) Ger Vermeulen private communication
#              30) David Pitcher private communication (1DmkIII)
#              31) Darryl Zurn private communication (A590IS)
#              32) Rich Taylor private communication (5D)
#              33) D.J. Cristi private communication
#              34) Andreas Huggel and Pascal de Bruijn private communication
#              35) Jan Boelsma private communication
#              36) Karl-Heinz Klotz private communication (http://www.dslr-forum.de/showthread.php?t=430900)
#              37) Vesa Kivisto private communication (30D)
#              38) Kurt Garloff private communication (5DmkII)
#              39) Irwin Poche private communication (5DmkII)
#              40) Jose Oliver-Didier private communication
#              41) http://www.cpanforum.com/threads/10730
#              42) Norbert Wasser private communication
#              43) Karsten Sote private communication
#              44) Hugh Griffiths private communication (5DmkII)
#              45) Mark Berger private communication (5DmkII)
#              46) Dieter Steiner private communication (7D)
#              47) http://www.exiv2.org/
#              48) Tomasz A. Kawecki private communication (550D, firmware 1.0.6, 1.0.8)
#              49) http://www.listware.net/201101/digikam-users/49795-digikam-users-re-lens-recognition.html
#              JD) Jens Duttke private communication
#------------------------------------------------------------------------------

package Image::ExifTool::Canon;

use strict;
use vars qw($VERSION %canonModelID);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;

sub WriteCanon($$$);
sub ProcessSerialData($$$);
sub ProcessFilters($$$);
sub SwapWords($);

$VERSION = '2.71';

# Note: Removed 'USM' from 'L' lenses since it is redundant - PH
# (or is it?  Ref 32 shows 5 non-USM L-type lenses)
my %canonLensTypes = ( #4
     Notes => q{
        Decimal values differentiate lenses which would otherwise have the same
        LensType, and are used by the Composite LensID tag when attempting to
        identify the specific lens model.
     },
     1 => 'Canon EF 50mm f/1.8',
     2 => 'Canon EF 28mm f/2.8',
     # (3 removed in current Kamisaka list)
     3 => 'Canon EF 135mm f/2.8 Soft', #15/32
     4 => 'Canon EF 35-105mm f/3.5-4.5 or Sigma Lens', #28
     4.1 => 'Sigma UC Zoom 35-135mm f/4-5.6',
     5 => 'Canon EF 35-70mm f/3.5-4.5', #32
     6 => 'Canon EF 28-70mm f/3.5-4.5 or Sigma or Tokina Lens', #32
     6.1 => 'Sigma 18-50mm f/3.5-5.6 DC', #23
     6.2 => 'Sigma 18-125mm f/3.5-5.6 DC IF ASP',
     6.3 => 'Tokina AF193-2 19-35mm f/3.5-4.5',
     6.4 => 'Sigma 28-80mm f/3.5-5.6 II Macro', #47
     7 => 'Canon EF 100-300mm f/5.6L', #15
     8 => 'Canon EF 100-300mm f/5.6 or Sigma or Tokina Lens', #32
     8.1 => 'Sigma 70-300mm f/4-5.6 [APO] DG Macro', #15 (both APO and non-APO, ref http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,2947.0.html)
     8.2 => 'Tokina AT-X242AF 24-200mm f/3.5-5.6', #15
     9 => 'Canon EF 70-210mm f/4', #32
     9.1 => 'Sigma 55-200mm f/4-5.6 DC', #34
    10 => 'Canon EF 50mm f/2.5 Macro or Sigma Lens', #10 (+ LSC Life Size Converter --> 70mm - PH)
    10.1 => 'Sigma 50mm f/2.8 EX', #4
    10.2 => 'Sigma 28mm f/1.8',
    10.3 => 'Sigma 105mm f/2.8 Macro EX', #15
    10.4 => 'Sigma 70mm f/2.8 EX DG Macro EF', #Jean-Michel Dubois
    11 => 'Canon EF 35mm f/2', #9
    13 => 'Canon EF 15mm f/2.8 Fisheye', #9
    14 => 'Canon EF 50-200mm f/3.5-4.5L', #32
    15 => 'Canon EF 50-200mm f/3.5-4.5', #32
    16 => 'Canon EF 35-135mm f/3.5-4.5', #32
    17 => 'Canon EF 35-70mm f/3.5-4.5A', #32
    18 => 'Canon EF 28-70mm f/3.5-4.5', #32
    20 => 'Canon EF 100-200mm f/4.5A', #32
    21 => 'Canon EF 80-200mm f/2.8L',
    22 => 'Canon EF 20-35mm f/2.8L or Tokina Lens', #32
    22.1 => 'Tokina AT-X280AF PRO 28-80mm f/2.8 Aspherical', #15
    23 => 'Canon EF 35-105mm f/3.5-4.5', #32
    24 => 'Canon EF 35-80mm f/4-5.6 Power Zoom', #32
    25 => 'Canon EF 35-80mm f/4-5.6 Power Zoom', #32
    26 => 'Canon EF 100mm f/2.8 Macro or Other Lens',
    26.1 => 'Cosina 100mm f/3.5 Macro AF',
    26.2 => 'Tamron SP AF 90mm f/2.8 Di Macro', #15
    26.3 => 'Tamron SP AF 180mm f/3.5 Di Macro', #15
    26.4 => 'Carl Zeiss Planar T* 50mm f/1.4', #PH
    27 => 'Canon EF 35-80mm f/4-5.6', #32
    28 => 'Canon EF 80-200mm f/4.5-5.6 or Tamron Lens', #32
    28.1 => 'Tamron SP AF 28-105mm f/2.8 LD Aspherical IF', #15
    28.2 => 'Tamron SP AF 28-75mm f/2.8 XR Di LD Aspherical [IF] Macro', #4
    28.3 => 'Tamron AF 70-300mm f/4.5-5.6 Di LD 1:2 Macro Zoom', #11
    28.4 => 'Tamron AF Aspherical 28-200mm f/3.8-5.6', #14
    29 => 'Canon EF 50mm f/1.8 II',
    30 => 'Canon EF 35-105mm f/4.5-5.6', #32
    31 => 'Canon EF 75-300mm f/4-5.6 or Tamron Lens', #32
    31.1 => 'Tamron SP AF 300mm f/2.8 LD IF', #15
    32 => 'Canon EF 24mm f/2.8 or Sigma Lens', #10
    32.1 => 'Sigma 15mm f/2.8 EX Fisheye', #11
    33 => 'Voigtlander or Zeiss Lens',
    33.1 => 'Voigtlander Ultron 40mm f/2 SLII Aspherical', #45
    33.2 => 'Zeiss Distagon 35mm T* f/2 ZE', #PH
    35 => 'Canon EF 35-80mm f/4-5.6', #32
    36 => 'Canon EF 38-76mm f/4.5-5.6', #32
    37 => 'Canon EF 35-80mm f/4-5.6 or Tamron Lens', #32
    37.1 => 'Tamron 70-200mm f/2.8 Di LD IF Macro', #PH
    37.2 => 'Tamron AF 28-300mm f/3.5-6.3 XR Di VC LD Aspherical [IF] Macro Model A20', #38
    37.3 => 'Tamron SP AF 17-50mm f/2.8 XR Di II VC LD Aspherical [IF]', #34
    37.4 => 'Tamron AF 18-270mm f/3.5-6.3 Di II VC LD Aspherical [IF] Macro', #http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,2937.0.html
    38 => 'Canon EF 80-200mm f/4.5-5.6', #32
    39 => 'Canon EF 75-300mm f/4-5.6',
    40 => 'Canon EF 28-80mm f/3.5-5.6',
    41 => 'Canon EF 28-90mm f/4-5.6', #32
    42 => 'Canon EF 28-200mm f/3.5-5.6 or Tamron Lens', #32
    42.1 => 'Tamron AF 28-300mm f/3.5-6.3 XR Di VC LD Aspherical [IF] Macro Model A20', #15
    43 => 'Canon EF 28-105mm f/4-5.6', #10
    44 => 'Canon EF 90-300mm f/4.5-5.6', #32
    45 => 'Canon EF-S 18-55mm f/3.5-5.6 [II]', #PH (same ID for version II, ref 20)
    46 => 'Canon EF 28-90mm f/4-5.6', #32
    48 => 'Canon EF-S 18-55mm f/3.5-5.6 IS', #20
    49 => 'Canon EF-S 55-250mm f/4-5.6 IS', #23
    50 => 'Canon EF-S 18-200mm f/3.5-5.6 IS',
    51 => 'Canon EF-S 18-135mm f/3.5-5.6 IS', #PH
    52 => 'Canon EF-S 18-55mm f/3.5-5.6 IS II', #PH
    94 => 'Canon TS-E 17mm f/4L', #42
    95 => 'Canon TS-E 24.0mm f/3.5 L II', #43
    124 => 'Canon MP-E 65mm f/2.8 1-5x Macro Photo', #9
    125 => 'Canon TS-E 24mm f/3.5L',
    126 => 'Canon TS-E 45mm f/2.8', #15
    127 => 'Canon TS-E 90mm f/2.8', #15
    129 => 'Canon EF 300mm f/2.8L', #32
    130 => 'Canon EF 50mm f/1.0L', #10/15
    131 => 'Canon EF 28-80mm f/2.8-4L or Sigma Lens', #32
    131.1 => 'Sigma 8mm f/3.5 EX DG Circular Fisheye', #15
    131.2 => 'Sigma 17-35mm f/2.8-4 EX DG Aspherical HSM', #15
    131.3 => 'Sigma 17-70mm f/2.8-4.5 DC Macro', #PH (NC)
    131.4 => 'Sigma APO 50-150mm f/2.8 [II] EX DC HSM', #15 ([II] ref PH)
    131.5 => 'Sigma APO 120-300mm f/2.8 EX DG HSM', #15
           # 'Sigma APO 120-300mm f/2.8 EX DG HSM + 1.4x', #15
           # 'Sigma APO 120-300mm f/2.8 EX DG HSM + 2x', #15
    132 => 'Canon EF 1200mm f/5.6L', #32
    134 => 'Canon EF 600mm f/4L IS', #15
    135 => 'Canon EF 200mm f/1.8L',
    136 => 'Canon EF 300mm f/2.8L',
    137 => 'Canon EF 85mm f/1.2L or Sigma or Tamron Lens', #10
    137.1 => 'Sigma 18-50mm f/2.8-4.5 DC OS HSM', #PH
    137.2 => 'Sigma 50-200mm f/4-5.6 DC OS HSM', #PH
    137.3 => 'Sigma 18-250mm f/3.5-6.3 DC OS HSM', #PH
    137.4 => 'Sigma 24-70mm f/2.8 IF EX DG HSM', #PH
    137.5 => 'Sigma 18-125mm f/3.8-5.6 DC OS HSM', #PH
    137.6 => 'Sigma 17-70mm f/2.8-4 DC Macro OS HSM', #http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,2819.0.html
    137.7 => 'Sigma 17-50mm f/2.8 OS HSM', #PH (from Exiv2)
    137.8 => 'Tamron AF 18-270mm f/3.5-6.3 Di II VC PZD', #(model B008)http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,3090.0.html
    138 => 'Canon EF 28-80mm f/2.8-4L', #32
    139 => 'Canon EF 400mm f/2.8L',
    140 => 'Canon EF 500mm f/4.5L', #32
    141 => 'Canon EF 500mm f/4.5L',
    142 => 'Canon EF 300mm f/2.8L IS', #15
    143 => 'Canon EF 500mm f/4L IS', #15
    144 => 'Canon EF 35-135mm f/4-5.6 USM', #26
    145 => 'Canon EF 100-300mm f/4.5-5.6 USM', #32
    146 => 'Canon EF 70-210mm f/3.5-4.5 USM', #32
    147 => 'Canon EF 35-135mm f/4-5.6 USM', #32
    148 => 'Canon EF 28-80mm f/3.5-5.6 USM', #32
    149 => 'Canon EF 100mm f/2 USM', #9
    150 => 'Canon EF 14mm f/2.8L or Sigma Lens', #10
    150.1 => 'Sigma 20mm EX f/1.8', #4
    150.2 => 'Sigma 30mm f/1.4 DC HSM', #15
    150.3 => 'Sigma 24mm f/1.8 DG Macro EX', #15
    151 => 'Canon EF 200mm f/2.8L',
    152 => 'Canon EF 300mm f/4L IS or Sigma Lens', #15
    152.1 => 'Sigma 12-24mm f/4.5-5.6 EX DG ASPHERICAL HSM', #15
    152.2 => 'Sigma 14mm f/2.8 EX Aspherical HSM', #15
    152.3 => 'Sigma 10-20mm f/4-5.6', #14
    152.4 => 'Sigma 100-300mm f/4', # (ref Bozi)
    153 => 'Canon EF 35-350mm f/3.5-5.6L or Sigma or Tamron Lens', #PH
    153.1 => 'Sigma 50-500mm f/4-6.3 APO HSM EX', #15
    153.2 => 'Tamron AF 28-300mm f/3.5-6.3 XR LD Aspherical [IF] Macro',
    153.3 => 'Tamron AF 18-200mm f/3.5-6.3 XR Di II LD Aspherical [IF] Macro Model A14', #15
    153.4 => 'Tamron 18-250mm f/3.5-6.3 Di II LD Aspherical [IF] Macro', #PH
    154 => 'Canon EF 20mm f/2.8 USM', #15
    155 => 'Canon EF 85mm f/1.8 USM',
    156 => 'Canon EF 28-105mm f/3.5-4.5 USM or Tamron Lens',
    156.1 => 'Tamron SP 70-300mm f/4.0-5.6 Di VC USD', #PH (model A005)
    160 => 'Canon EF 20-35mm f/3.5-4.5 USM or Tamron or Tokina Lens',
    160.1 => 'Tamron AF 19-35mm f/3.5-4.5', #44
    160.2 => 'Tokina AT-X 124 AF 12-24mm f/4 DX', #49 (not sure about specific model - PH)
    160.3 => 'Tokina AT-X 107 AF DX 10-17mm f/3.5-4.5 Fisheye', #PH (http://osdir.com/ml/digikam-devel/2011-04/msg00275.html)
    161 => 'Canon EF 28-70mm f/2.8L or Sigma or Tamron Lens',
    161.1 => 'Sigma 24-70mm f/2.8 EX',
    161.2 => 'Sigma 28-70mm f/2.8 EX', #PH (http://www.breezesys.com/forum/showthread.php?t=3718)
    161.3 => 'Tamron AF 17-50mm f/2.8 Di-II LD Aspherical', #40
    161.4 => 'Tamron 90mm f/2.8',
    162 => 'Canon EF 200mm f/2.8L', #32
    163 => 'Canon EF 300mm f/4L', #32
    164 => 'Canon EF 400mm f/5.6L', #32
    165 => 'Canon EF 70-200mm f/2.8 L',
    166 => 'Canon EF 70-200mm f/2.8 L + 1.4x',
    167 => 'Canon EF 70-200mm f/2.8 L + 2x',
    168 => 'Canon EF 28mm f/1.8 USM', #15
    169 => 'Canon EF 17-35mm f/2.8L or Sigma Lens', #15
    169.1 => 'Sigma 18-200mm f/3.5-6.3 DC OS', #23
    169.2 => 'Sigma 15-30mm f/3.5-4.5 EX DG Aspherical', #4
    169.3 => 'Sigma 18-50mm f/2.8 Macro', #26
    169.4 => 'Sigma 50mm f/1.4 EX DG HSM', #PH
    169.5 => 'Sigma 85mm f/1.4 EX DG HSM', #Rolando Ruzic
    169.6 => 'Sigma 30mm f/1.4 EX DC HSM', #Rodolfo Borges
    170 => 'Canon EF 200mm f/2.8L II', #9
    171 => 'Canon EF 300mm f/4L', #15
    172 => 'Canon EF 400mm f/5.6L', #32
    173 => 'Canon EF 180mm Macro f/3.5L or Sigma Lens', #9
    173.1 => 'Sigma 180mm EX HSM Macro f/3.5', #14
    173.2 => 'Sigma APO Macro 150mm f/2.8 EX DG HSM', #14
    174 => 'Canon EF 135mm f/2L or Sigma Lens', #9
    174.1 => 'Sigma 70-200mm f/2.8 EX DG APO OS HSM', #PH (probably version II of this lens)
    175 => 'Canon EF 400mm f/2.8L', #32
    176 => 'Canon EF 24-85mm f/3.5-4.5 USM',
    177 => 'Canon EF 300mm f/4L IS', #9
    178 => 'Canon EF 28-135mm f/3.5-5.6 IS',
    179 => 'Canon EF 24mm f/1.4L', #20
    180 => 'Canon EF 35mm f/1.4L', #9
    181 => 'Canon EF 100-400mm f/4.5-5.6L IS + 1.4x', #15
    182 => 'Canon EF 100-400mm f/4.5-5.6L IS + 2x',
    183 => 'Canon EF 100-400mm f/4.5-5.6L IS',
    184 => 'Canon EF 400mm f/2.8L + 2x', #15
    185 => 'Canon EF 600mm f/4L IS', #32
    186 => 'Canon EF 70-200mm f/4L', #9
    187 => 'Canon EF 70-200mm f/4L + 1.4x', #26
    188 => 'Canon EF 70-200mm f/4L + 2x', #PH
    189 => 'Canon EF 70-200mm f/4L + 2.8x', #32
    190 => 'Canon EF 100mm f/2.8 Macro',
    191 => 'Canon EF 400mm f/4 DO IS', #9
    193 => 'Canon EF 35-80mm f/4-5.6 USM', #32
    194 => 'Canon EF 80-200mm f/4.5-5.6 USM', #32
    195 => 'Canon EF 35-105mm f/4.5-5.6 USM', #32
    196 => 'Canon EF 75-300mm f/4-5.6 USM', #15/32
    197 => 'Canon EF 75-300mm f/4-5.6 IS USM',
    198 => 'Canon EF 50mm f/1.4 USM', #9
    199 => 'Canon EF 28-80mm f/3.5-5.6 USM', #32
    200 => 'Canon EF 75-300mm f/4-5.6 USM', #32
    201 => 'Canon EF 28-80mm f/3.5-5.6 USM', #32
    202 => 'Canon EF 28-80mm f/3.5-5.6 USM IV',
    208 => 'Canon EF 22-55mm f/4-5.6 USM', #32
    209 => 'Canon EF 55-200mm f/4.5-5.6', #32
    210 => 'Canon EF 28-90mm f/4-5.6 USM', #32
    211 => 'Canon EF 28-200mm f/3.5-5.6 USM', #15
    212 => 'Canon EF 28-105mm f/4-5.6 USM', #15
    213 => 'Canon EF 90-300mm f/4.5-5.6 USM',
    214 => 'Canon EF-S 18-55mm f/3.5-5.6 USM', #PH/34
    215 => 'Canon EF 55-200mm f/4.5-5.6 II USM',
    224 => 'Canon EF 70-200mm f/2.8L IS', #11
    225 => 'Canon EF 70-200mm f/2.8L IS + 1.4x', #11
    226 => 'Canon EF 70-200mm f/2.8L IS + 2x', #14
    227 => 'Canon EF 70-200mm f/2.8L IS + 2.8x', #32
    228 => 'Canon EF 28-105mm f/3.5-4.5 USM', #32
    229 => 'Canon EF 16-35mm f/2.8L', #PH
    230 => 'Canon EF 24-70mm f/2.8L', #9
    231 => 'Canon EF 17-40mm f/4L',
    232 => 'Canon EF 70-300mm f/4.5-5.6 DO IS USM', #15
    233 => 'Canon EF 28-300mm f/3.5-5.6L IS', #PH
    234 => 'Canon EF-S 17-85mm f4-5.6 IS USM', #19
    235 => 'Canon EF-S 10-22mm f/3.5-4.5 USM', #15
    236 => 'Canon EF-S 60mm f/2.8 Macro USM', #15
    237 => 'Canon EF 24-105mm f/4L IS', #15
    238 => 'Canon EF 70-300mm f/4-5.6 IS USM', #15
    239 => 'Canon EF 85mm f/1.2L II', #15
    240 => 'Canon EF-S 17-55mm f/2.8 IS USM', #15
    241 => 'Canon EF 50mm f/1.2L', #15
    242 => 'Canon EF 70-200mm f/4L IS', #PH
    243 => 'Canon EF 70-200mm f/4L IS + 1.4x', #15
    244 => 'Canon EF 70-200mm f/4L IS + 2x', #PH
    245 => 'Canon EF 70-200mm f/4L IS + 2.8x', #32
    246 => 'Canon EF 16-35mm f/2.8L II', #PH
    247 => 'Canon EF 14mm f/2.8L II USM', #32
    248 => 'Canon EF 200mm f/2L IS', #42
    249 => 'Canon EF 800mm f/5.6L IS', #35
    250 => 'Canon EF 24 f/1.4L II', #41
    251 => 'Canon EF 70-200mm f/2.8L IS II USM',
    254 => 'Canon EF 100mm f/2.8L Macro IS USM', #42
    # Note: LensType 488 (0x1e8) is reported as 232 (0xe8) in 7D CameraSettings
    488 => 'Canon EF-S 15-85mm f/3.5-5.6 IS USM', #PH
    489 => 'Canon EF 70-300mm f/4-5.6L IS USM', #Gerald Kapounek
);

# Canon model ID numbers (PH)
%canonModelID = (
    0x1010000 => 'PowerShot A30',
    0x1040000 => 'PowerShot S300 / Digital IXUS 300 / IXY Digital 300',
    0x1060000 => 'PowerShot A20',
    0x1080000 => 'PowerShot A10',
    0x1090000 => 'PowerShot S110 / Digital IXUS v / IXY Digital 200',
    0x1100000 => 'PowerShot G2',
    0x1110000 => 'PowerShot S40',
    0x1120000 => 'PowerShot S30',
    0x1130000 => 'PowerShot A40',
    0x1140000 => 'EOS D30',
    0x1150000 => 'PowerShot A100',
    0x1160000 => 'PowerShot S200 / Digital IXUS v2 / IXY Digital 200a',
    0x1170000 => 'PowerShot A200',
    0x1180000 => 'PowerShot S330 / Digital IXUS 330 / IXY Digital 300a',
    0x1190000 => 'PowerShot G3',
    0x1210000 => 'PowerShot S45',
    0x1230000 => 'PowerShot SD100 / Digital IXUS II / IXY Digital 30',
    0x1240000 => 'PowerShot S230 / Digital IXUS v3 / IXY Digital 320',
    0x1250000 => 'PowerShot A70',
    0x1260000 => 'PowerShot A60',
    0x1270000 => 'PowerShot S400 / Digital IXUS 400 / IXY Digital 400',
    0x1290000 => 'PowerShot G5',
    0x1300000 => 'PowerShot A300',
    0x1310000 => 'PowerShot S50',
    0x1340000 => 'PowerShot A80',
    0x1350000 => 'PowerShot SD10 / Digital IXUS i / IXY Digital L',
    0x1360000 => 'PowerShot S1 IS',
    0x1370000 => 'PowerShot Pro1',
    0x1380000 => 'PowerShot S70',
    0x1390000 => 'PowerShot S60',
    0x1400000 => 'PowerShot G6',
    0x1410000 => 'PowerShot S500 / Digital IXUS 500 / IXY Digital 500',
    0x1420000 => 'PowerShot A75',
    0x1440000 => 'PowerShot SD110 / Digital IXUS IIs / IXY Digital 30a',
    0x1450000 => 'PowerShot A400',
    0x1470000 => 'PowerShot A310',
    0x1490000 => 'PowerShot A85',
    0x1520000 => 'PowerShot S410 / Digital IXUS 430 / IXY Digital 450',
    0x1530000 => 'PowerShot A95',
    0x1540000 => 'PowerShot SD300 / Digital IXUS 40 / IXY Digital 50',
    0x1550000 => 'PowerShot SD200 / Digital IXUS 30 / IXY Digital 40',
    0x1560000 => 'PowerShot A520',
    0x1570000 => 'PowerShot A510',
    0x1590000 => 'PowerShot SD20 / Digital IXUS i5 / IXY Digital L2',
    0x1640000 => 'PowerShot S2 IS',
    0x1650000 => 'PowerShot SD430 / Digital IXUS Wireless / IXY Digital Wireless',
    0x1660000 => 'PowerShot SD500 / Digital IXUS 700 / IXY Digital 600',
    0x1668000 => 'EOS D60',
    0x1700000 => 'PowerShot SD30 / Digital IXUS i Zoom / IXY Digital L3',
    0x1740000 => 'PowerShot A430',
    0x1750000 => 'PowerShot A410',
    0x1760000 => 'PowerShot S80',
    0x1780000 => 'PowerShot A620',
    0x1790000 => 'PowerShot A610',
    0x1800000 => 'PowerShot SD630 / Digital IXUS 65 / IXY Digital 80',
    0x1810000 => 'PowerShot SD450 / Digital IXUS 55 / IXY Digital 60',
    0x1820000 => 'PowerShot TX1',
    0x1870000 => 'PowerShot SD400 / Digital IXUS 50 / IXY Digital 55',
    0x1880000 => 'PowerShot A420',
    0x1890000 => 'PowerShot SD900 / Digital IXUS 900 Ti / IXY Digital 1000',
    0x1900000 => 'PowerShot SD550 / Digital IXUS 750 / IXY Digital 700',
    0x1920000 => 'PowerShot A700',
    0x1940000 => 'PowerShot SD700 IS / Digital IXUS 800 IS / IXY Digital 800 IS',
    0x1950000 => 'PowerShot S3 IS',
    0x1960000 => 'PowerShot A540',
    0x1970000 => 'PowerShot SD600 / Digital IXUS 60 / IXY Digital 70',
    0x1980000 => 'PowerShot G7',
    0x1990000 => 'PowerShot A530',
    0x2000000 => 'PowerShot SD800 IS / Digital IXUS 850 IS / IXY Digital 900 IS',
    0x2010000 => 'PowerShot SD40 / Digital IXUS i7 / IXY Digital L4',
    0x2020000 => 'PowerShot A710 IS',
    0x2030000 => 'PowerShot A640',
    0x2040000 => 'PowerShot A630',
    0x2090000 => 'PowerShot S5 IS',
    0x2100000 => 'PowerShot A460',
    0x2120000 => 'PowerShot SD850 IS / Digital IXUS 950 IS / IXY Digital 810 IS',
    0x2130000 => 'PowerShot A570 IS',
    0x2140000 => 'PowerShot A560',
    0x2150000 => 'PowerShot SD750 / Digital IXUS 75 / IXY Digital 90',
    0x2160000 => 'PowerShot SD1000 / Digital IXUS 70 / IXY Digital 10',
    0x2180000 => 'PowerShot A550',
    0x2190000 => 'PowerShot A450',
    0x2230000 => 'PowerShot G9',
    0x2240000 => 'PowerShot A650 IS',
    0x2260000 => 'PowerShot A720 IS',
    0x2290000 => 'PowerShot SX100 IS',
    0x2300000 => 'PowerShot SD950 IS / Digital IXUS 960 IS / IXY Digital 2000 IS',
    0x2310000 => 'PowerShot SD870 IS / Digital IXUS 860 IS / IXY Digital 910 IS',
    0x2320000 => 'PowerShot SD890 IS / Digital IXUS 970 IS / IXY Digital 820 IS',
    0x2360000 => 'PowerShot SD790 IS / Digital IXUS 90 IS / IXY Digital 95 IS',
    0x2370000 => 'PowerShot SD770 IS / Digital IXUS 85 IS / IXY Digital 25 IS',
    0x2380000 => 'PowerShot A590 IS',
    0x2390000 => 'PowerShot A580',
    0x2420000 => 'PowerShot A470',
    0x2430000 => 'PowerShot SD1100 IS / Digital IXUS 80 IS / IXY Digital 20 IS',
    0x2460000 => 'PowerShot SX1 IS',
    0x2470000 => 'PowerShot SX10 IS',
    0x2480000 => 'PowerShot A1000 IS',
    0x2490000 => 'PowerShot G10',
    0x2510000 => 'PowerShot A2000 IS',
    0x2520000 => 'PowerShot SX110 IS',
    0x2530000 => 'PowerShot SD990 IS / Digital IXUS 980 IS / IXY Digital 3000 IS',
    0x2540000 => 'PowerShot SD880 IS / Digital IXUS 870 IS / IXY Digital 920 IS',
    0x2550000 => 'PowerShot E1',
    0x2560000 => 'PowerShot D10',
    0x2570000 => 'PowerShot SD960 IS / Digital IXUS 110 IS / IXY Digital 510 IS',
    0x2580000 => 'PowerShot A2100 IS',
    0x2590000 => 'PowerShot A480',
    0x2600000 => 'PowerShot SX200 IS',
    0x2610000 => 'PowerShot SD970 IS / Digital IXUS 990 IS / IXY Digital 830 IS',
    0x2620000 => 'PowerShot SD780 IS / Digital IXUS 100 IS / IXY Digital 210 IS',
    0x2630000 => 'PowerShot A1100 IS',
    0x2640000 => 'PowerShot SD1200 IS / Digital IXUS 95 IS / IXY Digital 110 IS',
    0x2700000 => 'PowerShot G11',
    0x2710000 => 'PowerShot SX120 IS',
    0x2720000 => 'PowerShot S90',
    0x2750000 => 'PowerShot SX20 IS',
    0x2760000 => 'PowerShot SD980 IS / Digital IXUS 200 IS / IXY Digital 930 IS',
    0x2770000 => 'PowerShot SD940 IS / Digital IXUS 120 IS / IXY Digital 220 IS',
    0x2800000 => 'PowerShot A495',
    0x2810000 => 'PowerShot A490',
    0x2820000 => 'PowerShot A3100 IS',
    0x2830000 => 'PowerShot A3000 IS',
    0x2840000 => 'PowerShot SD1400 IS / IXUS 130 / IXY 400F',
    0x2850000 => 'PowerShot SD1300 IS / IXUS 105 / IXY 200F',
    0x2860000 => 'PowerShot SD3500 IS / IXUS 210 / IXY 10S',
    0x2870000 => 'PowerShot SX210 IS',
    0x2880000 => 'PowerShot SD4000 IS / IXUS 300 HS / IXY 30S',
    0x2890000 => 'PowerShot SD4500 IS / IXUS 1000 HS / IXY 50S',
    0x2920000 => 'PowerShot G12',
    0x2930000 => 'PowerShot SX30 IS',
    0x2940000 => 'PowerShot SX130 IS',
    0x2950000 => 'PowerShot S95',
    0x2980000 => 'PowerShot A3300 IS',
    0x2990000 => 'PowerShot A3200 IS',
    0x3000000 => 'PowerShot ELPH 500 HS / IXUS 310 HS / IXY 31 S',
    0x3010000 => 'PowerShot Pro90 IS',
    0x3010001 => 'PowerShot A800',
    0x3020000 => 'PowerShot ELPH 100 HS / IXUS 115 HS / IXY 210F',
    0x3030000 => 'PowerShot SX230 HS',
    0x3040000 => 'PowerShot ELPH 300 HS / IXUS 220 HS / IXY 410F',
    0x3050000 => 'PowerShot A2200',
    0x3060000 => 'PowerShot A1200',
    0x3070000 => 'PowerShot SX220 HS',
    0x4040000 => 'PowerShot G1',
    0x6040000 => 'PowerShot S100 / Digital IXUS / IXY Digital',
    0x4007d673 => 'DC19/DC21/DC22',
    0x4007d674 => 'XH A1',
    0x4007d675 => 'HV10',
    0x4007d676 => 'MD130/MD140/MD150/MD160/ZR850',
    0x4007d777 => 'DC50', # (iVIS)
    0x4007d778 => 'HV20', # (iVIS)
    0x4007d779 => 'DC211', #29
    0x4007d77a => 'HG10',
    0x4007d77b => 'HR10', #29 (iVIS)
    0x4007d77d => 'MD255/ZR950',
    0x4007d81c => 'HF11',
    0x4007d878 => 'HV30',
    0x4007d87e => 'DC301/DC310/DC311/DC320/DC330',
    0x4007d87f => 'FS100',
    0x4007d880 => 'HF10', #29 (iVIS/VIXIA)
    0x4007d882 => 'HG20/HG21', # (VIXIA)
    0x4007d925 => 'HF21', # (LEGRIA)
    0x4007d926 => 'HF S11', # (LEGRIA)
    0x4007d978 => 'HV40', # (LEGRIA)
    0x4007d987 => 'DC410/DC420',
    0x4007d988 => 'FS19/FS20/FS21/FS22/FS200', # (LEGRIA)
    0x4007d989 => 'HF20/HF200', # (LEGRIA)
    0x4007d98a => 'HF S10/S100', # (LEGRIA/VIXIA)
    0x4007da8e => 'HF R16/R17/R18/R100/R106', # (LEGRIA/VIXIA)
    0x4007da8f => 'HF M31/M36/M300', # (LEGRIA/VIXIA, probably also HF M30)
    0x4007da90 => 'HF S20/S21/S200', # (LEGRIA/VIXIA)
    0x4007da92 => 'FS36/FS37/FS305/FS306/FS307',
    # NOTE: some pre-production models may have a model name of
    # "Canon EOS Kxxx", where "xxx" is the last 3 digits of the model ID below.
    # This has been observed for the 1DSmkIII/K215 and 400D/K236.
    0x80000001 => 'EOS-1D',
    0x80000167 => 'EOS-1DS',
    0x80000168 => 'EOS 10D',
    0x80000169 => 'EOS-1D Mark III',
    0x80000170 => 'EOS Digital Rebel / 300D / Kiss Digital',
    0x80000174 => 'EOS-1D Mark II',
    0x80000175 => 'EOS 20D',
    0x80000176 => 'EOS Digital Rebel XSi / 450D / Kiss X2',
    0x80000188 => 'EOS-1Ds Mark II',
    0x80000189 => 'EOS Digital Rebel XT / 350D / Kiss Digital N',
    0x80000190 => 'EOS 40D',
    0x80000213 => 'EOS 5D',
    0x80000215 => 'EOS-1Ds Mark III',
    0x80000218 => 'EOS 5D Mark II',
    0x80000232 => 'EOS-1D Mark II N',
    0x80000234 => 'EOS 30D',
    0x80000236 => 'EOS Digital Rebel XTi / 400D / Kiss Digital X', # and K236
    0x80000250 => 'EOS 7D',
    0x80000252 => 'EOS Rebel T1i / 500D / Kiss X3',
    0x80000254 => 'EOS Rebel XS / 1000D / Kiss F',
    0x80000261 => 'EOS 50D',
    0x80000270 => 'EOS Rebel T2i / 550D / Kiss X4',
    0x80000281 => 'EOS-1D Mark IV',
    0x80000286 => 'EOS Rebel T3i / 600D / Kiss X5',
    0x80000287 => 'EOS 60D',
    0x80000288 => 'EOS Rebel T3 / 1100D / Kiss X50',
);

my %canonQuality = (
    1 => 'Economy',
    2 => 'Normal',
    3 => 'Fine',
    4 => 'RAW',
    5 => 'Superfine',
    130 => 'Normal Movie', #22
);
my %canonImageSize = (
    0 => 'Large',
    1 => 'Medium',
    2 => 'Small',
    5 => 'Medium 1', #PH
    6 => 'Medium 2', #PH
    7 => 'Medium 3', #PH
    8 => 'Postcard', #PH (SD200 1600x1200 with DateStamp option)
    9 => 'Widescreen', #PH (SD900 3648x2048), 22 (HFS200 3264x1840)
    10 => 'Medium Widescreen', #22 (HFS200 1920x1080)
    14 => 'Small 1', #PH
    15 => 'Small 2', #PH
    16 => 'Small 3', #PH
    128 => '640x480 Movie', #PH (7D 60fps)
    129 => 'Medium Movie', #22
    130 => 'Small Movie', #22
    137 => '1280x720 Movie', #PH (S95 24fps; D60 50fps)
    142 => '1920x1080 Movie', #PH (D60 25fps)
);
my %canonWhiteBalance = (
    # -1='Click", -2='Pasted' ?? - PH
    0 => 'Auto',
    1 => 'Daylight',
    2 => 'Cloudy',
    3 => 'Tungsten',
    4 => 'Fluorescent',
    5 => 'Flash',
    6 => 'Custom',
    7 => 'Black & White',
    8 => 'Shade',
    9 => 'Manual Temperature (Kelvin)',
    10 => 'PC Set1', #PH
    11 => 'PC Set2', #PH
    12 => 'PC Set3', #PH
    14 => 'Daylight Fluorescent', #3
    15 => 'Custom 1', #PH
    16 => 'Custom 2', #PH
    17 => 'Underwater', #3
    18 => 'Custom 3', #PH
    19 => 'Custom 4', #PH
    20 => 'PC Set4', #PH
    21 => 'PC Set5', #PH
    # 22 - Custom 2?
    # 23 - Custom 3?
    # 30 - Click White Balance?
    # 31 - Shot Settings?
    # 137 - Tungsten?
    # 138 - White Fluorescent?
    # 139 - Fluorescent H?
    # 140 - Manual?
);

# picture styles used by the 5D
# (styles 0x4X may be downloaded from Canon)
# (called "ColorMatrix" in 1D owner manual)
my %pictureStyles = ( #12
    0x00 => 'None', #PH
    0x01 => 'Standard', #15
    0x02 => 'Portrait', #15
    0x03 => 'High Saturation', #15
    0x04 => 'Adobe RGB', #15
    0x05 => 'Low Saturation', #15
    0x06 => 'CM Set 1', #PH
    0x07 => 'CM Set 2', #PH
    # "ColorMatrix" values end here
    0x21 => 'User Def. 1',
    0x22 => 'User Def. 2',
    0x23 => 'User Def. 3',
    # "External" styles currently available from Canon are Nostalgia, Clear,
    # Twilight and Emerald.  The "User Def" styles change to these "External"
    # codes when these styles are installed in the camera
    0x41 => 'PC 1', #PH
    0x42 => 'PC 2', #PH
    0x43 => 'PC 3', #PH
    0x81 => 'Standard',
    0x82 => 'Portrait',
    0x83 => 'Landscape',
    0x84 => 'Neutral',
    0x85 => 'Faithful',
    0x86 => 'Monochrome',
    0x87 => 'Auto', #PH
);
my %userDefStyles = ( #12/48
    Notes => q{
        Base style for user-defined picture styles.  PC values represent external
        picture styles which may be downloaded from Canon and installed in the
        camera.
    },
    0x41 => 'PC 1',
    0x42 => 'PC 2',
    0x43 => 'PC 3',
    0x81 => 'Standard',
    0x82 => 'Portrait',
    0x83 => 'Landscape',
    0x84 => 'Neutral',
    0x85 => 'Faithful',
    0x86 => 'Monochrome',
);

# picture style tag information for CameraInfo550D
my %psConv = (
    -559038737 => 'n/a', # = 0xdeadbeef ! LOL
    OTHER => sub { return shift },
);
my %psInfo = (
    Format => 'int32s',
    PrintHex => 1,
    PrintConv => \%psConv,
);

# ValueConv that makes long values binary type
my %longBin = (
    ValueConv => 'length($val) > 64 ? \$val : $val',
    ValueConvInv => '$val',
);

# conversions, etc for CameraColorCalibration tags
my %cameraColorCalibration = (
    Format => 'int16s[4]',
    Unknown => 1,
    PrintConv => 'sprintf("%4d %4d %4d (%dK)", split(" ",$val))',
    PrintConvInv => '$val=~s/\s+/ /g; $val=~tr/()K//d; $val',
);

# conversions, etc for PowerShot CameraColorCalibration tags
my %cameraColorCalibration2 = (
    Format => 'int16s[5]',
    Unknown => 1,
    PrintConv => 'sprintf("%4d %4d %4d %4d (%dK)", split(" ",$val))',
    PrintConvInv => '$val=~s/\s+/ /g; $val=~tr/()K//d; $val',
);
# conversions, etc for byte-swapped FocusDistance tags
my %focusDistanceByteSwap = (
    # this is very odd (little-endian number on odd boundary),
    # but it does seem to work better with my sample images - PH
    Format => 'int16uRev',
    ValueConv => '$val / 100',
    ValueConvInv => '$val * 100',
    PrintConv => '$val > 655.345 ? "inf" : "$val m"',
    PrintConvInv => '$val =~ s/ ?m$//; IsFloat($val) ? $val : 655.35',
);

# common attributes for writable BinaryData directories
my %binaryDataAttrs = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
);

#------------------------------------------------------------------------------
# Canon EXIF Maker Notes
%Image::ExifTool::Canon::Main = (
    WRITE_PROC => \&WriteCanon,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x1 => {
        Name => 'CanonCameraSettings',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::CameraSettings',
        },
    },
    0x2 => {
        Name => 'CanonFocalLength',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::FocalLength',
        },
    },
    0x3 => {
        Name => 'CanonFlashInfo',
        Unknown => 1,
    },
    0x4 => {
        Name => 'CanonShotInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::ShotInfo',
        },
    },
    0x5 => {
        Name => 'CanonPanorama',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::Panorama',
        },
    },
    0x6 => {
        Name => 'CanonImageType',
        Writable => 'string',
        Groups => { 2 => 'Image' },
    },
    0x7 => {
        Name => 'CanonFirmwareVersion',
        Writable => 'string',
    },
    0x8 => {
        Name => 'FileNumber',
        Writable => 'int32u',
        Groups => { 2 => 'Image' },
        PrintConv => '$_=$val,s/(\d+)(\d{4})/$1-$2/,$_',
        PrintConvInv => '$val=~s/-//g;$val',
    },
    0x9 => {
        Name => 'OwnerName',
        Writable => 'string',
        # pad to 32 bytes (including null terminator which will be added)
        # to avoid bug which crashes DPP if length is 4 bytes
        ValueConvInv => '$val .= "\0" x (31 - length $val) if length $val < 31; $val',
    },
    0xa => {
        Name => 'UnknownD30',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::UnknownD30',
        },
    },
    0xc => [   # square brackets for a conditional list
        {
            # D30
            Name => 'SerialNumber',
            Condition => '$$self{Model} =~ /EOS D30\b/',
            Writable => 'int32u',
            PrintConv => 'sprintf("%.4x%.5d",$val>>16,$val&0xffff)',
            PrintConvInv => '$val=~/(.*)-?(\d{5})$/ ? (hex($1)<<16)+$2 : undef',
        },
        {
            # serial number of 1D/1Ds/1D Mark II/1Ds Mark II is usually
            # displayed w/o leeding zeros (ref 7) (1D uses 6 digits - PH)
            Name => 'SerialNumber',
            Condition => '$$self{Model} =~ /EOS-1D/',
            Writable => 'int32u',
            PrintConv => 'sprintf("%.6u",$val)',
            PrintConvInv => '$val',
        },
        {
            # all other models (D60,300D,350D,REBEL,10D,20D,etc)
            Name => 'SerialNumber',
            Writable => 'int32u',
            PrintConv => 'sprintf("%.10u",$val)',
            PrintConvInv => '$val',
        },
    ],
    0xd => [
        {
            Name => 'CanonCameraInfo1D',
            # (save size of this record as "CameraInfoCount" for later tests)
            Condition => '($$self{CameraInfoCount} = $count) and $$self{Model} =~ /\b1DS?$/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::CameraInfo1D',
            },
        },
        {
            Name => 'CanonCameraInfo1DmkII',
            Condition => '$$self{Model} =~ /\b1Ds? Mark II$/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::CameraInfo1DmkII',
            },
        },
        {
            Name => 'CanonCameraInfo1DmkIIN',
            Condition => '$$self{Model} =~ /\b1Ds? Mark II N$/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::CameraInfo1DmkIIN',
            },
        },
        {
            Name => 'CanonCameraInfo1DmkIII',
            Condition => '$$self{Model} =~ /\b1Ds? Mark III$/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::CameraInfo1DmkIII',
            },
        },
        {
            Name => 'CanonCameraInfo1DmkIV',
            Condition => '$$self{Model} =~ /\b1D Mark IV$/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::CameraInfo1DmkIV',
            },
        },
        {
            Name => 'CanonCameraInfo5D',
            Condition => '$$self{Model} =~ /EOS 5D$/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::CameraInfo5D',
            },
        },
        {
            Name => 'CanonCameraInfo5DmkII',
            Condition => '$$self{Model} =~ /EOS 5D Mark II$/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::CameraInfo5DmkII',
            },
        },
        {
            Name => 'CanonCameraInfo7D',
            Condition => '$$self{Model} =~ /EOS 7D$/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::CameraInfo7D',
            },
        },
        {
            Name => 'CanonCameraInfo40D',
            Condition => '$$self{Model} =~ /EOS 40D$/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::CameraInfo40D',
            },
        },
        {
            Name => 'CanonCameraInfo50D',
            Condition => '$$self{Model} =~ /EOS 50D$/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::CameraInfo50D',
            },
        },
        {
            Name => 'CanonCameraInfo60D',
            Condition => '$$self{Model} =~ /EOS 60D$/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::CameraInfo60D',
            },
        },
        {
            Name => 'CanonCameraInfo450D',
            Condition => '$$self{Model} =~ /\b(450D|REBEL XSi|Kiss X2)\b/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::CameraInfo450D',
            },
        },
        {
            Name => 'CanonCameraInfo500D',
            Condition => '$$self{Model} =~ /\b(500D|REBEL T1i|Kiss X3)\b/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::CameraInfo500D',
            },
        },
        {
            Name => 'CanonCameraInfo550D',
            Condition => '$$self{Model} =~ /\b(550D|REBEL T2i|Kiss X4)\b/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::CameraInfo550D',
            },
        },
        {
            Name => 'CanonCameraInfo1000D',
            Condition => '$$self{Model} =~ /\b(1000D|REBEL XS|Kiss F)\b/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::CameraInfo1000D',
            },
        },
        {
            Name => 'CanonCameraInfoPowerShot',
            # valid if format is int32u[138] or int32u[148]
            Condition => '$format eq "int32u" and ($count == 138 or $count == 148)',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::CameraInfoPowerShot',
            },
        },
        {
            Name => 'CanonCameraInfoPowerShot2',
            # valid if format is int32u[162], int32u[167], int32u[171] or int32u[264]
            Condition => q{
                $format eq "int32u" and ($count == 156 or $count == 162 or
                $count == 167 or $count == 171 or $count == 264)
            },
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::CameraInfoPowerShot2',
            },
        },
        {
            Name => 'CanonCameraInfoUnknown32',
            Condition => '$format =~ /^int32/',
            # (counts of 72, 85, 86, 93, 94, 96, 104) - PH
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::CameraInfoUnknown32',
            },
        },
        {
            Name => 'CanonCameraInfoUnknown16',
            Condition => '$format =~ /^int16/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::CameraInfoUnknown16',
            },
        },
        {
            Name => 'CanonCameraInfoUnknown',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::CameraInfoUnknown',
            },
        },
    ],
    0xe => {
        Name => 'CanonFileLength',
        Writable => 'int32u',
        Groups => { 2 => 'Image' },
    },
    0xf => [
        {   # used by 1DmkII, 1DSmkII and 1DmkIIN
            Name => 'CustomFunctions1D',
            Condition => '$$self{Model} =~ /EOS-1D/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions1D',
            },
        },
        {
            Name => 'CustomFunctions5D',
            Condition => '$$self{Model} =~ /EOS 5D/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions5D',
            },
        },
        {
            Name => 'CustomFunctions10D',
            Condition => '$$self{Model} =~ /EOS 10D/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions10D',
            },
        },
        {
            Name => 'CustomFunctions20D',
            Condition => '$$self{Model} =~ /EOS 20D/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions20D',
            },
        },
        {
            Name => 'CustomFunctions30D',
            Condition => '$$self{Model} =~ /EOS 30D/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions30D',
            },
        },
        {
            Name => 'CustomFunctions350D',
            Condition => '$$self{Model} =~ /\b(350D|REBEL XT|Kiss Digital N)\b/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions350D',
            },
        },
        {
            Name => 'CustomFunctions400D',
            Condition => '$$self{Model} =~ /\b(400D|REBEL XTi|Kiss Digital X|K236)\b/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions400D',
            },
        },
        {
            Name => 'CustomFunctionsD30',
            Condition => '$$self{Model} =~ /EOS D30\b/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::FunctionsD30',
            },
        },
        {
            Name => 'CustomFunctionsD60',
            Condition => '$$self{Model} =~ /EOS D60\b/',
            SubDirectory => {
                # the stored size in the D60 apparently doesn't include the size word:
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size-2,$size)',
                # (D60 custom functions are basically the same as D30)
                TagTable => 'Image::ExifTool::CanonCustom::FunctionsD30',
            },
        },
        {
            Name => 'CustomFunctionsUnknown',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::FuncsUnknown',
            },
        },
    ],
    0x10 => { #PH
        Name => 'CanonModelID',
        Writable => 'int32u',
        PrintHex => 1,
        SeparateTable => 1,
        PrintConv => \%canonModelID,
    },
    0x11 => { #PH
        Name => 'MovieInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::MovieInfo',
        },
    },
    0x12 => {
        Name => 'CanonAFInfo',
        # not really a condition -- just need to store the count for later
        Condition => '$$self{AFInfoCount} = $count',
        SubDirectory => {
            # this record does not begin with a length word, so it
            # has to be validated differently
            Validate => 'Image::ExifTool::Canon::ValidateAFInfo($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::AFInfo',
        },
    },
    0x13 => { #PH
        Name => 'ThumbnailImageValidArea',
        # left,right,top,bottom edges of image in thumbnail, or all zeros for full frame
        Notes => 'all zeros for full frame',
        Writable => 'int16u',
        Count => 4,
    },
    0x15 => { #PH
        # display format for serial number
        Name => 'SerialNumberFormat',
        Writable => 'int32u',
        PrintHex => 1,
        PrintConv => {
            0x90000000 => 'Format 1',
            0xa0000000 => 'Format 2',
        },
    },
    0x1a => { #15
        Name => 'SuperMacro',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'On (1)',
            2 => 'On (2)',
        },
    },
    0x1c => { #PH (A570IS)
        Name => 'DateStampMode',
        Writable => 'int16u',
        Notes => 'used only in postcard mode',
        PrintConv => {
            0 => 'Off',
            1 => 'Date',
            2 => 'Date & Time',
        },
    },
    0x1d => { #PH
        Name => 'MyColors',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::MyColors',
        },
    },
    0x1e => { #PH
        Name => 'FirmwareRevision',
        Writable => 'int32u',
        # as a hex number: 0xAVVVRR00, where (a bit of guessing here...)
        #  A = 'a' for alpha, 'b' for beta?
        #  V = version? (100,101 for normal releases, 100,110,120,130,170 for alpha/beta)
        #  R = revision? (01-07, except 00 for alpha/beta releases)
        PrintConv => q{
            my $rev = sprintf("%.8x", $val);
            my ($rel, $v1, $v2, $r1, $r2) = ($rev =~ /^(.)(.)(..)0?(.+)(..)$/);
            my %r = ( a => 'Alpha ', b => 'Beta ', '0' => '' );
            $rel = defined $r{$rel} ? $r{$rel} : "Unknown($rel) ";
            return "$rel$v1.$v2 rev $r1.$r2",
        },
        PrintConvInv => q{
            $_=$val; s/Alpha ?/a/i; s/Beta ?/b/i;
            s/Unknown ?\((.)\)/$1/i; s/ ?rev ?(.)\./0$1/; s/ ?rev ?//;
            tr/a-fA-F0-9//dc; return hex $_;
        },
    },
    # 0x1f - used for red-eye-corrected images - PH (A570IS)
    # 0x22 - values 1 and 2 are 2 and 1 for flash pics, 0 otherwise - PH (A570IS)
    0x23 => { #31
        Name => 'Categories',
        Writable => 'int32u',
        Format => 'int32u', # (necessary to perform conversion for Condition)
        Notes => '2 values: 1. always 8, 2. Categories',
        Count => '2',
        Condition => '$$valPt =~ /^\x08\0\0\0/',
        ValueConv => '$val =~ s/^8 //; $val',
        ValueConvInv => '"8 $val"',
        PrintConvColumns => 2,
        PrintConv => { BITMASK => {
            0 => 'People',
            1 => 'Scenery',
            2 => 'Events',
            3 => 'User 1',
            4 => 'User 2',
            5 => 'User 3',
            6 => 'To Do',
        } },
    },
    0x24 => { #PH
        Name => 'FaceDetect1',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::FaceDetect1',
        },
    },
    0x25 => { #PH
        Name => 'FaceDetect2',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::FaceDetect2',
        },
    },
    0x26 => { #PH (A570IS,1DmkIII)
        Name => 'CanonAFInfo2',
        Condition => '$$valPt !~ /^\0\0\0\0/', # (data may be all zeros in thumbnail of 60D MOV video)
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::AFInfo2',
        },
    },
    # 0x27 - value 1 is 1 for high ISO pictures, 0 otherwise
    #        value 4 is 9 for Flexizone and FaceDetect AF, 1 for Centre AF, 0 otherwise (SX10IS)
    0x28 => { #JD
        # bytes 0-1=sequence number (encrypted), 2-5=date/time (encrypted) (ref JD)
        Name => 'ImageUniqueID',
        Format => 'undef',
        Writable => 'int8u',
        Groups => { 2 => 'Image' },
        RawConv => '$val eq "\0" x 16 ? undef : $val',
        ValueConv => 'unpack("H*", $val)',
        ValueConvInv => 'pack("H*", $val)',
    },
    # 0x2d - changes with categories (ref 31)
    # 0x44 - ShootInfo
    # 0x62 - UserSetting
    0x81 => { #13
        Name => 'RawDataOffset',
        # (can't yet write 1D raw files)
        # Writable => 'int32u',
        # Protected => 2,
    },
    0x83 => { #PH
        Name => 'OriginalDecisionDataOffset',
        Writable => 'int32u',
        OffsetPair => 1, # (just used as a flag, since this tag has no pair)
        # this is an offset to the original decision data block
        # (offset relative to start of file in JPEG images, but NOT DNG images!)
        IsOffset => '$val and $$exifTool{FILE_TYPE} ne "JPEG"',
        Protected => 2,
        DataTag => 'OriginalDecisionData',
    },
    0x90 => {   # used by 1D and 1Ds
        Name => 'CustomFunctions1D',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::CanonCustom::Functions1D',
        },
    },
    0x91 => { #PH
        Name => 'PersonalFunctions',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::CanonCustom::PersonalFuncs',
        },
    },
    0x92 => { #PH
        Name => 'PersonalFunctionValues',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::CanonCustom::PersonalFuncValues',
        },
    },
    0x93 => {
        Name => 'CanonFileInfo', # (ShootInfoEx)
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::FileInfo',
        },
    },
    0x94 => { #PH
        # AF points for 1D (45 points in 5 rows)
        Name => 'AFPointsInFocus1D',
        Notes => 'EOS 1D -- 5 rows: A1-7, B1-10, C1-11, D1-10, E1-7, center point is C6',
        PrintConv => 'Image::ExifTool::Canon::PrintAFPoints1D($val)',
    },
    0x95 => { #PH (observed in 5D sample image)
        Name => 'LensModel',
        Writable => 'string',
    },
    0x96 => [ #PH
        {
            Name => 'SerialInfo',
            Condition => '$$self{Model} =~ /EOS 5D/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::SerialInfo' },
        },
        {
            Name => 'InternalSerialNumber',
            Writable => 'string',
            # remove trailing 0xff's if they exist (Kiss X3)
            ValueConv => '$val=~s/\xff+$//; $val',
            ValueConvInv => '$val',
        },
    ],
    0x97 => { #PH
        Name => 'DustRemovalData',
        # some interesting stuff is stored in here, like LensType and InternalSerialNumber...
        Writable => 'undef',
        Flags => [ 'Binary', 'Protected' ],
    },
    0x98 => { #PH
        Name => 'CropInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::CropInfo',
        },
    },
    0x99 => { #PH (EOS 1D Mark III, 40D, etc)
        Name => 'CustomFunctions2',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::CanonCustom::Functions2',
        },
    },
    0x9a => { #PH
        Name => 'AspectInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::AspectInfo',
        },
    },
    0xa0 => {
        Name => 'ProcessingInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::Processing',
        },
    },
    0xa1 => { Name => 'ToneCurveTable', %longBin }, #PH
    0xa2 => { Name => 'SharpnessTable', %longBin }, #PH
    0xa3 => { Name => 'SharpnessFreqTable', %longBin }, #PH
    0xa4 => { Name => 'WhiteBalanceTable', %longBin }, #PH
    0xa9 => {
        Name => 'ColorBalance',
        SubDirectory => {
            # this offset is necessary because the table is interpreted as short rationals
            # (4 bytes long) but the first entry is 2 bytes into the table.
            Start => '$valuePtr + 2',
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart-2,$size+2)',
            TagTable => 'Image::ExifTool::Canon::ColorBalance',
        },
    },
    0xaa => {
        Name => 'MeasuredColor',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::MeasuredColor',
        },
    },
    0xae => {
        Name => 'ColorTemperature',
        Writable => 'int16u',
    },
    0xb0 => { #PH
        Name => 'CanonFlags',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::Flags',
        },
    },
    0xb1 => { #PH
        Name => 'ModifiedInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::ModifiedInfo',
        },
    },
    0xb2 => { Name => 'ToneCurveMatching', %longBin }, #PH
    0xb3 => { Name => 'WhiteBalanceMatching', %longBin }, #PH
    0xb4 => { #PH
        Name => 'ColorSpace',
        Writable => 'int16u',
        PrintConv => {
            1 => 'sRGB',
            2 => 'Adobe RGB',
        },
    },
    0xb6 => {
        Name => 'PreviewImageInfo',
        SubDirectory => {
            # Note: the first word of this block gives the correct block size in bytes, but
            # the size is wrong by a factor of 2 in the IFD, so we must account for this
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size/2)',
            TagTable => 'Image::ExifTool::Canon::PreviewImageInfo',
        },
    },
    0xd0 => { #PH
        Name => 'VRDOffset',
        Writable => 'int32u',
        OffsetPair => 1, # (just used as a flag, since this tag has no pair)
        Protected => 2,
        DataTag => 'CanonVRD',
        Notes => 'offset of VRD "recipe data" if it exists',
    },
    0xe0 => { #12
        Name => 'SensorInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::SensorInfo',
        },
    },
    0x4001 => [ #13
        {   # (int16u[582]) - 20D and 350D
            Condition => '$count == 582',
            Name => 'ColorData1',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::ColorData1',
            },
        },
        {   # (int16u[653]) - 1DmkII and 1DSmkII
            Condition => '$count == 653',
            Name => 'ColorData2',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::ColorData2',
            },
        },
        {   # (int16u[796]) - 1DmkIIN, 5D, 30D, 400D
            Condition => '$count == 796',
            Name => 'ColorData3',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::ColorData3',
            },
        },
        {   # (int16u[692|674|702|1227|1250|1251|1337])
            # 40D (692), 1DmkIII (674), 1DSmkIII (702), 450D/1000D (1227)
            # 50D/5DmkII (1250), 500D/7D_pre-prod/1DmkIV_pre-prod (1251),
            # 1DmkIV/7D/550D_pre-prod (1337), 550D (1338), 1100D (1346)
            Condition => q{
                $count == 692  or $count == 674  or $count == 702 or
                $count == 1227 or $count == 1250 or $count == 1251 or
                $count == 1337 or $count == 1338 or $count == 1346
            },
            Name => 'ColorData4',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::ColorData4',
            },
        },
        {   # (int16u[5120]) - G10
            Condition => '$count == 5120',
            Name => 'ColorData5',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::ColorData5',
            },
        },
        {   # (int16u[1273]) - 600D
            Condition => '$count == 1273',
            Name => 'ColorData6',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::ColorData6',
            },
        },
        {
            Name => 'ColorDataUnknown',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::ColorDataUnknown',
            },
        },
    ],
    0x4002 => { #PH
        # unknown data block in some JPEG and CR2 images
        # (5kB for most models, but 22kb for 5D and 30D)
        Name => 'CRWParam',
        Format => 'undef',
        Flags => [ 'Unknown', 'Binary' ],
    },
    0x4003 => { #PH
        Name => 'ColorInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::ColorInfo',
        },
    },
    0x4005 => { #PH
        Name => 'Flavor',
        Notes => 'unknown 49kB block, not copied to JPEG images',
        # 'Drop' because not found in JPEG images (too large for APP1 anyway)
        Flags => [ 'Unknown', 'Binary', 'Drop' ],
    },
    0x4008 => { #PH guess (1DmkIII)
        Name => 'BlackLevel', # (BasePictStyleOfUser)
        Unknown => 1,
    },
    0x4010 => { #http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,2933.0.html
        Name => 'CustomPictureStyleFileName',
        Writable => 'string',
    },
    0x4013 => { #PH
        Name => 'AFMicroAdj',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::AFMicroAdj',
        },
    },
    0x4015 => {
        Name => 'VignettingCorr',
        Condition => '$$valPt !~ /^\0\0\0\0/', # (data may be all zeros for 60D)
        SubDirectory => {
            # (the size word is at byte 2 in this structure)
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart+2,$size)',
            TagTable => 'Image::ExifTool::Canon::VignettingCorr',
        },
    },
    0x4016 => {
        Name => 'VignettingCorr2',
        SubDirectory => {
            # (the size word is actually 4 bytes, but it doesn't matter if little-endian)
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::VignettingCorr2',
        },
    },
    0x4018 => { #PH
        Name => 'LightingOpt',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::LightingOpt',
        }
    },
    0x4019 => { #20
        Name => 'LensInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::LensInfo',
        }
    },
    0x4020 => { #PH
        Name => 'AmbienceInfo',
        Condition => '$$valPt !~ /^\0\0\0\0/', # (data may be all zeros for 60D)
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::Ambience',
        }
    },
    0x4024 => { #PH
        Name => 'FilterInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::FilterInfo',
        }
    },
);

#..............................................................................
# Canon camera settings (MakerNotes tag 0x01)
# BinaryData (keys are indices into the int16s array)
%Image::ExifTool::Canon::CameraSettings = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    DATAMEMBER => [ 22, 25 ],   # necessary for writing
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => {
        Name => 'MacroMode',
        PrintConv => {
            1 => 'Macro',
            2 => 'Normal',
        },
    },
    2 => {
        Name => 'SelfTimer',
        # Custom timer mode if bit 0x4000 is set - PH (A570IS)
        PrintConv => q{
            return 'Off' unless $val;
            return (($val&0xfff) / 10) . ' s' . ($val & 0x4000 ? ', Custom' : '');
        },
        PrintConvInv => q{
            return 0 if $val =~ /^Off/i;
            $val =~ s/\s*s(ec)?\b//i;
            $val =~ s/,?\s*Custom$//i ? ($val*10) | 0x4000 : $val*10;
        },
    },
    3 => {
        Name => 'Quality',
        PrintConv => \%canonQuality,
    },
    4 => {
        Name => 'CanonFlashMode',
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'On',
            3 => 'Red-eye reduction',
            4 => 'Slow-sync',
            5 => 'Red-eye reduction (Auto)',
            6 => 'Red-eye reduction (On)',
            16 => 'External flash', # not set in D30 or 300D
        },
    },
    5 => {
        Name => 'ContinuousDrive',
        PrintConv => {
            0 => 'Single',
            1 => 'Continuous',
            2 => 'Movie', #PH
            3 => 'Continuous, Speed Priority', #PH
            4 => 'Continuous, Low', #PH
            5 => 'Continuous, High', #PH
            6 => 'Silent Single', #PH
            # 32-34 - Self-timer?
        },
    },
    7 => {
        Name => 'FocusMode',
        PrintConv => {
            0 => 'One-shot AF',
            1 => 'AI Servo AF',
            2 => 'AI Focus AF',
            3 => 'Manual Focus (3)',
            4 => 'Single',
            5 => 'Continuous',
            6 => 'Manual Focus (6)',
           16 => 'Pan Focus', #PH
           # 137 - Single?
        },
    },
    9 => { #PH
        Name => 'RecordMode',
        RawConv => '$val==-1 ? undef : $val', #22
        PrintConv => {
            1 => 'JPEG',
            2 => 'CRW+THM', # (300D,etc)
            3 => 'AVI+THM', # (30D)
            4 => 'TIF', # +THM? (1Ds) (unconfirmed)
            5 => 'TIF+JPEG', # (1D) (unconfirmed)
            6 => 'CR2', # +THM? (1D,30D,350D)
            7 => 'CR2+JPEG', # (S30)
            9 => 'Video', # (S95 MOV)
        },
    },
    10 => {
        Name => 'CanonImageSize',
        PrintConvColumns => 2,
        PrintConv => \%canonImageSize,
    },
    11 => {
        Name => 'EasyMode',
        PrintConvColumns => 3,
        PrintConv => {
            0 => 'Full auto',
            1 => 'Manual',
            2 => 'Landscape',
            3 => 'Fast shutter',
            4 => 'Slow shutter',
            5 => 'Night',
            6 => 'Gray Scale', #PH
            7 => 'Sepia',
            8 => 'Portrait',
            9 => 'Sports',
            10 => 'Macro',
            11 => 'Black & White', #PH
            12 => 'Pan focus',
            13 => 'Vivid', #PH
            14 => 'Neutral', #PH
            15 => 'Flash Off',  #8
            16 => 'Long Shutter', #PH
            17 => 'Super Macro', #PH
            18 => 'Foliage', #PH
            19 => 'Indoor', #PH
            20 => 'Fireworks', #PH
            21 => 'Beach', #PH
            22 => 'Underwater', #PH
            23 => 'Snow', #PH
            24 => 'Kids & Pets', #PH
            25 => 'Night Snapshot', #PH
            26 => 'Digital Macro', #PH
            27 => 'My Colors', #PH
            28 => 'Movie Snap', #PH
            29 => 'Super Macro 2', #PH
            30 => 'Color Accent', #18
            31 => 'Color Swap', #18
            32 => 'Aquarium', #18
            33 => 'ISO 3200', #18
            34 => 'ISO 6400', #PH
            35 => 'Creative Light Effect', #PH
            36 => 'Easy', #PH
            37 => 'Quick Shot', #PH
            38 => 'Creative Auto', #39
            39 => 'Zoom Blur', #PH
            40 => 'Low Light', #PH
            41 => 'Nostalgic', #PH
            42 => 'Super Vivid', #PH (SD4500)
            43 => 'Poster Effect', #PH (SD4500)
            44 => 'Face Self-timer', #PH
            45 => 'Smile', #PH
            46 => 'Wink Self-timer', #PH
            47 => 'Fisheye Effect', #PH (SX30IS)
            48 => 'Miniature Effect', #PH (SD4500)
            49 => 'High-speed Burst', #PH
            50 => 'Best Image Selection', #PH
            51 => 'High Dynamic Range', #PH (S95)
            52 => 'Handheld Night Scene', #PH
            59 => 'Scene Intelligent Auto', #PH (T3i)
            257 => 'Spotlight', #PH
            258 => 'Night 2', #PH
            259 => 'Night+',
            260 => 'Super Night', #PH
            261 => 'Sunset', #PH (SX10IS)
            263 => 'Night Scene', #PH
            264 => 'Surface', #PH
            265 => 'Low Light 2', #PH
        },
    },
    12 => {
        Name => 'DigitalZoom',
        PrintConv => {
            0 => 'None',
            1 => '2x',
            2 => '4x',
            3 => 'Other',  # value obtained from 2*$val[37]/$val[36]
        },
    },
    13 => {
        Name => 'Contrast',
        RawConv => '$val == 0x7fff ? undef : $val',
        %Image::ExifTool::Exif::printParameter,
    },
    14 => {
        Name => 'Saturation',
        RawConv => '$val == 0x7fff ? undef : $val',
        %Image::ExifTool::Exif::printParameter,
    },
    15 => {
        Name => 'Sharpness',
        RawConv => '$val == 0x7fff ? undef : $val',
        Notes => q{
            some models use a range of -2 to +2 where 0 is normal sharpening, and
            others use a range of 0 to 7 where 0 is no sharpening
        },
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    16 => {
        Name => 'CameraISO',
        RawConv => '$val == 0x7fff ? undef : $val',
        ValueConv => 'Image::ExifTool::Canon::CameraISO($val)',
        ValueConvInv => 'Image::ExifTool::Canon::CameraISO($val,1)',
    },
    17 => {
        Name => 'MeteringMode',
        PrintConv => {
            0 => 'Default', # older Ixus
            1 => 'Spot',
            2 => 'Average', #PH
            3 => 'Evaluative',
            4 => 'Partial',
            5 => 'Center-weighted average',
        },
    },
    18 => {
        # this is always 2 for the 300D - PH
        Name => 'FocusRange',
        PrintConv => {
            0 => 'Manual',
            1 => 'Auto',
            2 => 'Not Known',
            3 => 'Macro',
            4 => 'Very Close', #PH
            5 => 'Close', #PH
            6 => 'Middle Range', #PH
            7 => 'Far Range',
            8 => 'Pan Focus',
            9 => 'Super Macro', #PH
            10=> 'Infinity', #PH
        },
    },
    19 => {
        Name => 'AFPoint',
        Flags => 'PrintHex',
        RawConv => '$val==0 ? undef : $val',
        PrintConv => {
            0x2005 => 'Manual AF point selection',
            0x3000 => 'None (MF)',
            0x3001 => 'Auto AF point selection',
            0x3002 => 'Right',
            0x3003 => 'Center',
            0x3004 => 'Left',
            0x4001 => 'Auto AF point selection',
            0x4006 => 'Face Detect', #PH (A570IS)
        },
    },
    20 => {
        Name => 'CanonExposureMode',
        PrintConv => {
            0 => 'Easy',
            1 => 'Program AE',
            2 => 'Shutter speed priority AE',
            3 => 'Aperture-priority AE',
            4 => 'Manual',
            5 => 'Depth-of-field AE',
            6 => 'M-Dep', #PH
            7 => 'Bulb', #30
        },
    },
    22 => { #4
        Name => 'LensType',
        RawConv => '$val ? $$self{LensType}=$val : undef', # don't use if value is zero
        Notes => 'this value is incorrect for EOS 7D images with lenses of type 256 or greater',
        SeparateTable => 1,
        DataMember => 'LensType',
        PrintConv => \%canonLensTypes,
    },
    23 => {
        Name => 'LongFocal',
        Format => 'int16u',
        # this is a bit tricky, but we need the FocalUnits to convert this to mm
        RawConvInv => '$val * ($$self{FocalUnits} || 1)',
        ValueConv => '$val / ($$self{FocalUnits} || 1)',
        ValueConvInv => '$val',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm//;$val',
    },
    24 => {
        Name => 'ShortFocal',
        Format => 'int16u',
        RawConvInv => '$val * ($$self{FocalUnits} || 1)',
        ValueConv => '$val / ($$self{FocalUnits} || 1)',
        ValueConvInv => '$val',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm//;$val',
    },
    25 => {
        Name => 'FocalUnits',
        # conversion from raw focal length values to mm
        DataMember => 'FocalUnits',
        RawConv => '$$self{FocalUnits} = $val',
        PrintConv => '"$val/mm"',
        PrintConvInv => '$val=~s/\s*\/?\s*mm//;$val',
    },
    26 => { #9
        Name => 'MaxAperture',
        RawConv => '$val > 0 ? $val : undef',
        ValueConv => 'exp(Image::ExifTool::Canon::CanonEv($val)*log(2)/2)',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(log($val)*2/log(2))',
        PrintConv => 'sprintf("%.2g",$val)',
        PrintConvInv => '$val',
    },
    27 => { #PH
        Name => 'MinAperture',
        RawConv => '$val > 0 ? $val : undef',
        ValueConv => 'exp(Image::ExifTool::Canon::CanonEv($val)*log(2)/2)',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(log($val)*2/log(2))',
        PrintConv => 'sprintf("%.2g",$val)',
        PrintConvInv => '$val',
    },
    28 => {
        Name => 'FlashActivity',
        RawConv => '$val==-1 ? undef : $val',
    },
    29 => {
        Name => 'FlashBits',
        PrintConvColumns => 2,
        PrintConv => { BITMASK => {
            0 => 'Manual', #PH
            1 => 'TTL', #PH
            2 => 'A-TTL', #PH
            3 => 'E-TTL', #PH
            4 => 'FP sync enabled',
            7 => '2nd-curtain sync used',
            11 => 'FP sync used',
            13 => 'Built-in',
            14 => 'External', #(may not be set in manual mode - ref 37)
        } },
    },
    32 => {
        Name => 'FocusContinuous',
        RawConv => '$val==-1 ? undef : $val',
        PrintConv => {
            0 => 'Single',
            1 => 'Continuous',
            8 => 'Manual', #22
        },
    },
    33 => { #PH
        Name => 'AESetting',
        RawConv => '$val==-1 ? undef : $val',
        PrintConv => {
            0 => 'Normal AE',
            1 => 'Exposure Compensation',
            2 => 'AE Lock',
            3 => 'AE Lock + Exposure Comp.',
            4 => 'No AE',
        },
    },
    34 => { #PH
        Name => 'ImageStabilization',
        RawConv => '$val==-1 ? undef : $val',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'On, Shot Only', #15 (panning for SX10IS)
            3 => 'On, Panning', #PH (A570IS)
            4 => 'On, Video', #PH (SX30IS)
        },
    },
    35 => { #PH
        Name => 'DisplayAperture',
        RawConv => '$val ? $val : undef',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    36 => 'ZoomSourceWidth', #PH
    37 => 'ZoomTargetWidth', #PH
    39 => { #22
        Name => 'SpotMeteringMode',
        RawConv => '$val==-1 ? undef : $val',
        PrintConv => {
            0 => 'Center',
            1 => 'AF Point',
        },
    },
    40 => { #PH
        Name => 'PhotoEffect',
        RawConv => '$val==-1 ? undef : $val',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Off',
            1 => 'Vivid',
            2 => 'Neutral',
            3 => 'Smooth',
            4 => 'Sepia',
            5 => 'B&W',
            6 => 'Custom',
            100 => 'My Color Data',
        },
    },
    41 => { #PH (A570IS)
        Name => 'ManualFlashOutput',
        PrintHex => 1,
        PrintConv => {
            0 => 'n/a',
            0x500 => 'Full',
            0x502 => 'Medium',
            0x504 => 'Low',
            0x7fff => 'n/a', # (EOS models)
        },
    },
    # 41 => non-zero for manual flash intensity - PH (A570IS)
    42 => {
        Name => 'ColorTone',
        RawConv => '$val == 0x7fff ? undef : $val',
        %Image::ExifTool::Exif::printParameter,
    },
    46 => { #PH
        Name => 'SRAWQuality',
        RawConv => '$val==-1 ? undef : $val',
        PrintConv => {
            0 => 'n/a',
            1 => 'sRAW1 (mRAW)',
            2 => 'sRAW2 (sRAW)',
        },
    },
);

# focal length information (MakerNotes tag 0x02)
%Image::ExifTool::Canon::FocalLength = (
    %binaryDataAttrs,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0 => { #9
        Name => 'FocalType',
        RawConv => '$val ? $val : undef', # don't use if value is zero
        PrintConv => {
            1 => 'Fixed',
            2 => 'Zoom',
        },
    },
    1 => {
        Name => 'FocalLength',
        # the EXIF FocalLength is more reliable, so set this priority to zero
        Priority => 0,
        RawConv => '$val ? $val : undef', # don't use if value is zero
        RawConvInv => q{
            my $focalUnits = $$self{FocalUnits};
            unless ($focalUnits) {
                $focalUnits = 1;
                # (this happens when writing FocalLength to CRW images)
                $self->Warn("FocalUnits not available for FocalLength conversion (1 assumed)");
            }
            return $val * $focalUnits;
        },
        ValueConv => '$val / ($$self{FocalUnits} || 1)',
        ValueConvInv => '$val',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm//;$val',
    },
    2 => [ #4
        {
            Name => 'FocalPlaneXSize',
            Notes => q{
                these focal plane sizes are only valid for some models, and are affected by
                digital zoom if applied
            },
            # this conversion is valid only for PowerShot models and these EOS models:
            # D30, D60, 1D, 1DS, 5D, 10D, 20D, 30D, 300D, 350D, and 400D
            Condition => q{
                $$self{Model} !~ /EOS/ or
                $$self{Model} =~ /\b(1DS?|5D|D30|D60|10D|20D|30D|K236)$/ or
                $$self{Model} =~ /\b((300D|350D|400D) DIGITAL|REBEL( XTi?)?|Kiss Digital( [NX])?)$/
            },
            # focal plane image dimensions in 1/1000 inch -- convert to mm
            RawConv => '$val < 40 ? undef : $val',  # must be reasonable
            ValueConv => '$val * 25.4 / 1000',
            ValueConvInv => 'int($val * 1000 / 25.4 + 0.5)',
            PrintConv => 'sprintf("%.2f mm",$val)',
            PrintConvInv => '$val=~s/\s*mm$//;$val',
        },{
            Name => 'FocalPlaneXUnknown',
            Unknown => 1,
        },
    ],
    3 => [ #4
        {
            Name => 'FocalPlaneYSize',
            Condition => q{
                $$self{Model} !~ /EOS/ or
                $$self{Model} =~ /\b(1DS?|5D|D30|D60|10D|20D|30D|K236)$/ or
                $$self{Model} =~ /\b((300D|350D|400D) DIGITAL|REBEL( XTi?)?|Kiss Digital( [NX])?)$/
            },
            RawConv => '$val < 40 ? undef : $val',  # must be reasonable
            ValueConv => '$val * 25.4 / 1000',
            ValueConvInv => 'int($val * 1000 / 25.4 + 0.5)',
            PrintConv => 'sprintf("%.2f mm",$val)',
            PrintConvInv => '$val=~s/\s*mm$//;$val',
        },{
            Name => 'FocalPlaneYUnknown',
            Unknown => 1,
        },
    ],
);

# Canon shot information (MakerNotes tag 0x04)
# BinaryData (keys are indices into the int16s array)
%Image::ExifTool::Canon::ShotInfo = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    DATAMEMBER => [ 19 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    1 => { #PH
        Name => 'AutoISO',
        Notes => 'actual ISO used = BaseISO * AutoISO / 100',
        ValueConv => 'exp($val/32*log(2))*100',
        ValueConvInv => '32*log($val/100)/log(2)',
        PrintConv => 'sprintf("%.0f",$val)',
        PrintConvInv => '$val',
    },
    2 => {
        Name => 'BaseISO',
        Priority => 0,
        RawConv => '$val ? $val : undef',
        ValueConv => 'exp($val/32*log(2))*100/32',
        ValueConvInv => '32*log($val*32/100)/log(2)',
        PrintConv => 'sprintf("%.0f",$val)',
        PrintConvInv => '$val',
    },
    3 => { #9/PH
        Name => 'MeasuredEV',
        Notes => q{
            this is the Canon name for what could better be called MeasuredLV, and
            should be close to the calculated LightValue for a proper exposure with most
            models
        },
        # empirical offset of +5 seems to be good for EOS models, but maybe
        # the offset should be less by up to 1 EV for some PowerShot models
        ValueConv => '$val / 32 + 5',
        ValueConvInv => '($val - 5) * 32',
        PrintConv => 'sprintf("%.2f",$val)',
        PrintConvInv => '$val',
    },
    4 => { #2, 9
        Name => 'TargetAperture',
        RawConv => '$val > 0 ? $val : undef',
        ValueConv => 'exp(Image::ExifTool::Canon::CanonEv($val)*log(2)/2)',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(log($val)*2/log(2))',
        PrintConv => 'sprintf("%.2g",$val)',
        PrintConvInv => '$val',
    },
    5 => { #2
        Name => 'TargetExposureTime',
        # ignore obviously bad values (also, -32768 may be used for n/a)
        # (note that a few models always write 0: DC211, and video models)
        RawConv => '($val > -1000 and ($val or $$self{Model}=~/(EOS|PowerShot|IXUS|IXY)/))? $val : undef',
        ValueConv => 'exp(-Image::ExifTool::Canon::CanonEv($val)*log(2))',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(-log($val)/log(2))',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    6 => {
        Name => 'ExposureCompensation',
        ValueConv => 'Image::ExifTool::Canon::CanonEv($val)',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv($val)',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    7 => {
        Name => 'WhiteBalance',
        PrintConv => \%canonWhiteBalance,
        SeparateTable => 1,
    },
    8 => { #PH
        Name => 'SlowShutter',
        PrintConv => {
            -1 => 'n/a',
            0 => 'Off',
            1 => 'Night Scene',
            2 => 'On',
            3 => 'None',
        },
    },
    9 => {
        Name => 'SequenceNumber',
        Description => 'Shot Number In Continuous Burst',
    },
    10 => { #PH/17
        Name => 'OpticalZoomCode',
        Groups => { 2 => 'Camera' },
        Notes => 'for many PowerShot models, a this is 0-6 for wide-tele zoom',
        # (for many models, 0-6 represent 0-100% zoom, but it is always 8 for
        #  EOS models, and I have seen values of 16,20,28,32 and 39 too...)
        # - set to 8 for "n/a" by Canon software (ref 22)
        PrintConv => '$val == 8 ? "n/a" : $val',
        PrintConvInv => '$val =~ /[a-z]/i ? 8 : $val',
    },
    # 11 - (8 for all EOS samples, [0,8] for other models - PH)
    12 => { #37
        Name => 'CameraTemperature',
        Condition => '$$self{Model} =~ /EOS/ and $$self{Model} !~ /EOS-1DS?$/',
        Groups => { 2 => 'Camera' },
        Notes => 'newer EOS models only',
        # usually zero if not valid for an EOS model (exceptions: 1D, 1DS)
        RawConv => '$val ? $val : undef',
        ValueConv => '$val - 128',
        ValueConvInv => '$val + 128',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    13 => { #PH
        Name => 'FlashGuideNumber',
        RawConv => '$val==-1 ? undef : $val',
        ValueConv => '$val / 32',
        ValueConvInv => '$val * 32',
    },
    # AF points for Ixus and IxusV cameras - 02/17/04 M. Rommel (also D30/D60 - PH)
    14 => { #2
        Name => 'AFPointsInFocus',
        Notes => 'used by D30, D60 and some PowerShot/Ixus models',
        Groups => { 2 => 'Camera' },
        Flags => 'PrintHex',
        RawConv => '$val==0 ? undef : $val',
        PrintConvColumns => 2,
        PrintConv => {
            0x3000 => 'None (MF)',
            0x3001 => 'Right',
            0x3002 => 'Center',
            0x3003 => 'Center+Right',
            0x3004 => 'Left',
            0x3005 => 'Left+Right',
            0x3006 => 'Left+Center',
            0x3007 => 'All',
        },
    },
    15 => {
        Name => 'FlashExposureComp',
        Description => 'Flash Exposure Compensation',
        ValueConv => 'Image::ExifTool::Canon::CanonEv($val)',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv($val)',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    16 => {
        Name => 'AutoExposureBracketing',
        PrintConv => {
            -1 => 'On',
            0 => 'Off',
            1 => 'On (shot 1)',
            2 => 'On (shot 2)',
            3 => 'On (shot 3)',
        },
    },
    17 => {
        Name => 'AEBBracketValue',
        ValueConv => 'Image::ExifTool::Canon::CanonEv($val)',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv($val)',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    18 => { #22
        Name => 'ControlMode',
        PrintConv => {
            0 => 'n/a',
            1 => 'Camera Local Control',
            3 => 'Computer Remote Control',
        },
    },
    19 => {
        Name => 'FocusDistanceUpper',
        DataMember => 'FocusDistanceUpper',
        Format => 'int16u',
        Notes => 'FocusDistance tags are only extracted if FocusDistanceUpper is non-zero',
        RawConv => '($$self{FocusDistanceUpper} = $val) || undef',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
        PrintConv => '$val > 655.345 ? "inf" : "$val m"',
        PrintConvInv => '$val =~ s/ ?m$//; IsFloat($val) ? $val : 655.35',
    },
    20 => {
        Name => 'FocusDistanceLower', # (seems to be the upper distance for the 400D)
        Condition => '$$self{FocusDistanceUpper}',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
        PrintConv => '$val > 655.345 ? "inf" : "$val m"',
        PrintConvInv => '$val =~ s/ ?m$//; IsFloat($val) ? $val : 655.35',
    },
    21 => {
        Name => 'FNumber',
        Priority => 0,
        RawConv => '$val ? $val : undef',
        # approximate big translation table by simple calculation - PH
        ValueConv => 'exp(Image::ExifTool::Canon::CanonEv($val)*log(2)/2)',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(log($val)*2/log(2))',
        PrintConv => 'sprintf("%.2g",$val)',
        PrintConvInv => '$val',
    },
    22 => [
        {
            Name => 'ExposureTime',
            # encoding is different for 20D and 350D (darn!)
            # (but note that encoding is the same for TargetExposureTime - PH)
            Condition => '$$self{Model} =~ /\b(20D|350D|REBEL XT|Kiss Digital N)\b/',
            Priority => 0,
            # many models write 0 here in JPEG images (even though 0 is the
            # value for an exposure time of 1 sec), but apparently a value of 0
            # is valid in a CRW image (=1s, D60 sample)
            RawConv => '($val or $$self{FILE_TYPE} eq "CRW") ? $val : undef',
            # approximate big translation table by simple calculation - PH
            ValueConv => 'exp(-Image::ExifTool::Canon::CanonEv($val)*log(2))*1000/32',
            ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(-log($val*32/1000)/log(2))',
            PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
            PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        },
        {
            Name => 'ExposureTime',
            Priority => 0,
            # many models write 0 here in JPEG images (even though 0 is the
            # value for an exposure time of 1 sec), but apparently a value of 0
            # is valid in a CRW image (=1s, D60 sample)
            RawConv => '($val or $$self{FILE_TYPE} eq "CRW") ? $val : undef',
            # approximate big translation table by simple calculation - PH
            ValueConv => 'exp(-Image::ExifTool::Canon::CanonEv($val)*log(2))',
            ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(-log($val)/log(2))',
            PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
            PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        },
    ],
    23 => { #37
        Name => 'MeasuredEV2',
        Description => 'Measured EV 2',
        RawConv => '$val ? $val : undef',
        ValueConv => '$val / 8 - 6',
        ValueConvInv => 'int(($val + 6) * 8 + 0.5)',
    },
    24 => {
        Name => 'BulbDuration',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    # 25 - (usually 0, but 1 for 2s timer?, 19 for small AVI, 14 for large
    #       AVI, and -6 and -10 for shots 1 and 2 with stitch assist - PH)
    26 => { #15
        Name => 'CameraType',
        Groups => { 2 => 'Camera' },
        PrintConv => {
            0 => 'n/a',
            248 => 'EOS High-end',
            250 => 'Compact',
            252 => 'EOS Mid-range',
            255 => 'DV Camera', #PH
        },
    },
    27 => {
        Name => 'AutoRotate',
        RawConv => '$val >= 0 ? $val : undef',
        PrintConv => {
           -1 => 'n/a', # (set to -1 when rotated by Canon software)
            0 => 'None',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 180',
            3 => 'Rotate 270 CW',
        },
    },
    28 => { #15
        Name => 'NDFilter',
        PrintConv => { -1 => 'n/a', 0 => 'Off', 1 => 'On' },
    },
    29 => {
        Name => 'SelfTimer2',
        RawConv => '$val >= 0 ? $val : undef',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    33 => { #PH (A570IS)
        Name => 'FlashOutput',
        RawConv => '($$self{Model}=~/(PowerShot|IXUS|IXY)/ or $val) ? $val : undef',
        Notes => q{
            used only for PowerShot models, this has a maximum value of 500 for models
            like the A570IS
        },
    },
);

# Canon panorama information (MakerNotes tag 0x05)
%Image::ExifTool::Canon::Panorama = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    # 0 - values: always 1
    # 1 - values: 0,256,512(3 sequential L->R images); 0,-256(2 R->L images)
    2 => 'PanoramaFrameNumber', #(some models this is always 0)
    # 3 - values: 160(SX10IS,A570IS); 871(S30)
    # 4 - values: always 0
    5 => {
        Name => 'PanoramaDirection',
        PrintConv => {
            0 => 'Left to Right',
            1 => 'Right to Left',
            2 => 'Bottom to Top',
            3 => 'Top to Bottom',
            4 => '2x2 Matrix (Clockwise)',
        },
     },
);

# D30 color information (MakerNotes tag 0x0a)
%Image::ExifTool::Canon::UnknownD30 = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
);

#..............................................................................
# common CameraInfo tag definitions
my %ciFNumber = (
    Name => 'FNumber',
    Format => 'int8u',
    Groups => { 2 => 'Image' },
    RawConv => '$val ? $val : undef',
    ValueConv => 'exp(($val-8)/16*log(2))',
    ValueConvInv => 'log($val)*16/log(2)+8',
    PrintConv => 'sprintf("%.2g",$val)',
    PrintConvInv => '$val',
);
my %ciExposureTime = (
    Name => 'ExposureTime',
    Format => 'int8u',
    Groups => { 2 => 'Image' },
    RawConv => '$val ? $val : undef',
    ValueConv => 'exp(4*log(2)*(1-Image::ExifTool::Canon::CanonEv($val-24)))',
    ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(1-log($val)/(4*log(2)))+24',
    PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
);
my %ciISO = (
    Name => 'ISO',
    Format => 'int8u',
    Groups => { 2 => 'Image' },
    ValueConv => '100*exp(($val/8-9)*log(2))',
    ValueConvInv => '(log($val/100)/log(2)+9)*8',
    PrintConv => 'sprintf("%.0f",$val)',
    PrintConvInv => '$val',
);
my %ciCameraTemperature = (
    Name => 'CameraTemperature',
    Format => 'int8u',
    ValueConv => '$val - 128',
    ValueConvInv => '$val + 128',
    PrintConv => '"$val C"',
    PrintConvInv => '$val=~s/ ?C//; $val',
);
my %ciMacroMagnification = (
    Name => 'MacroMagnification',
    Notes => 'currently decoded only for the MP-E 65mm f/2.8 1-5x Macro Photo',
    Condition => '$$self{LensType} and $$self{LensType} == 124',
    # 75=1x, 44=5x, log relationship
    ValueConv => 'exp((75-$val) * log(2) * 3 / 40)',
    ValueConvInv => '$val > 0 ? 75 - log($val) / log(2) * 40 / 3 : undef',
    PrintConv => 'sprintf("%.1fx",$val)',
    PrintConvInv => '$val=~s/\s*x//; $val',
);
my %ciFocalLength = (
    Name => 'FocalLength',
    Format => 'int16uRev', # (just to make things confusing, the focal lengths are big-endian)
    # ignore if zero
    RawConv => '$val ? $val : undef',
    PrintConv => '"$val mm"',
    PrintConvInv => '$val=~s/\s*mm//;$val',
);
my %ciShortFocal = (
    Name => 'ShortFocal',
    Format => 'int16uRev', # byte order is big-endian
    PrintConv => '"$val mm"',
    PrintConvInv => '$val=~s/\s*mm//;$val',
);
my %ciLongFocal = (
    Name => 'LongFocal',
    Format => 'int16uRev', # byte order is big-endian
    PrintConv => '"$val mm"',
    PrintConvInv => '$val=~s/\s*mm//;$val',
);

#..............................................................................
# Camera information for 1D and 1DS (MakerNotes tag 0x0d)
# (ref 15 unless otherwise noted)
%Image::ExifTool::Canon::CameraInfo1D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,  # these tags are not reliable since they change with firmware version
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        Information in the "CameraInfo" records is tricky to decode because the
        encodings are very different than in other Canon records (even sometimes
        switching endianness between values within a single camera), plus there is
        considerable variation in format from model to model. The first table below
        lists CameraInfo tags for the 1D and 1DS.
    },
    0x04 => { %ciExposureTime }, #9
    0x0a => {
        Name => 'FocalLength',
        Format => 'int16u',
        # ignore if zero
        RawConv => '$val ? $val : undef',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm//;$val',
    },
    0x0d => { #9
        Name => 'LensType',
        Format => 'int16uRev', # value is little-endian
        SeparateTable => 1,
        RawConv => '$val ? $val : undef', # don't use if value is zero
        PrintConv => \%canonLensTypes,
    },
    0x0e => {
        Name => 'ShortFocal',
        Format => 'int16u',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm//;$val',
    },
    0x10 => {
        Name => 'LongFocal',
        Format => 'int16u',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm//;$val',
    },
    0x41 => {
        Name => 'SharpnessFrequency', # PatternSharpness?
        Condition => '$$self{Model} =~ /\b1D$/',
        Notes => '1D only',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'n/a',
            1 => 'Lowest',
            2 => 'Low',
            3 => 'Standard',
            4 => 'High',
            5 => 'Highest',
        },
    },
    0x42 => {
        Name => 'Sharpness',
        Format => 'int8s',
        Condition => '$$self{Model} =~ /\b1D$/',
        Notes => '1D only',
    },
    0x44 => {
        Name => 'WhiteBalance',
        Condition => '$$self{Model} =~ /\b1D$/',
        Notes => '1D only',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x47 => {
        Name => 'SharpnessFrequency', # PatternSharpness?
        Condition => '$$self{Model} =~ /\b1DS$/',
        Notes => '1DS only',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'n/a',
            1 => 'Lowest',
            2 => 'Low',
            3 => 'Standard',
            4 => 'High',
            5 => 'Highest',
        },
    },
    0x48 => [
        {
            Name => 'ColorTemperature',
            Format => 'int16u',
            Condition => '$$self{Model} =~ /\b1D$/',
            Notes => '1D only',
        },
        {
            Name => 'Sharpness',
            Format => 'int8s',
            Condition => '$$self{Model} =~ /\b1DS$/',
            Notes => '1DS only',
        },
    ],
    0x4a => {
        Name => 'WhiteBalance',
        Condition => '$$self{Model} =~ /\b1DS$/',
        Notes => '1DS only',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x4b => {
        Name => 'PictureStyle',
        Condition => '$$self{Model} =~ /\b1D$/',
        Notes => "1D only, called 'Color Matrix' in owner's manual",
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0x4e => {
        Name => 'ColorTemperature',
        Format => 'int16u',
        Condition => '$$self{Model} =~ /\b1DS$/',
        Notes => '1DS only',
    },
    0x51 => {
        Name => 'PictureStyle',
        Condition => '$$self{Model} =~ /\b1DS$/',
        Notes => '1DS only',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
);

# Camera information for 1DmkII and 1DSmkII (MakerNotes tag 0x0d)
# (ref 15 unless otherwise noted)
%Image::ExifTool::Canon::CameraInfo1DmkII = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the 1DmkII and 1DSmkII.',
    0x04 => { %ciExposureTime }, #9
    0x09 => { %ciFocalLength }, #9
    0x0c => { #9
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        RawConv => '$val ? $val : undef', # don't use if value is zero
        PrintConv => \%canonLensTypes,
    },
    0x11 => { %ciShortFocal }, #9
    0x13 => { %ciLongFocal }, #9
    0x2d => { #9
        Name => 'FocalType',
        PrintConv => {
           0 => 'Fixed',
           2 => 'Zoom',
        },
    },
    0x36 => {
        Name => 'WhiteBalance',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x37 => {
        Name => 'ColorTemperature',
        Format => 'int16uRev',
    },
    0x39 => {
        Name => 'CanonImageSize',
        Format => 'int16u',
        PrintConvColumns => 2,
        PrintConv => \%canonImageSize,
    },
    0x66 => {
        Name => 'JPEGQuality',
        Notes => 'a number from 1 to 10',
    },
    0x6c => { #12
        Name => 'PictureStyle',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0x6e => {
        Name => 'Saturation',
        Format => 'int8s',
        %Image::ExifTool::Exif::printParameter,
    },
    0x6f => {
        Name => 'ColorTone',
        Format => 'int8s',
        %Image::ExifTool::Exif::printParameter,
    },
    0x72 => {
        Name => 'Sharpness',
        Format => 'int8s',
    },
    0x73 => {
        Name => 'Contrast',
        Format => 'int8s',
        %Image::ExifTool::Exif::printParameter,
    },
    0x75 => {
        Name => 'ISO',
        Format => 'string[5]',
    },
);

# Camera information for the 1DmkIIN (MakerNotes tag 0x0d)
# (ref 9 unless otherwise noted)
%Image::ExifTool::Canon::CameraInfo1DmkIIN = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the 1DmkIIN.',
    0x04 => { %ciExposureTime },
    0x09 => { %ciFocalLength },
    0x0c => {
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        RawConv => '$val ? $val : undef', # don't use if value is zero
        PrintConv => \%canonLensTypes,
    },
    0x11 => { %ciShortFocal },
    0x13 => { %ciLongFocal },
    0x36 => { #15
        Name => 'WhiteBalance',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x37 => { #15
        Name => 'ColorTemperature',
        Format => 'int16uRev',
    },
    0x73 => { #15
        Name => 'PictureStyle',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0x74 => { #15
        Name => 'Sharpness',
        Format => 'int8s',
    },
    0x75 => { #15
        Name => 'Contrast',
        Format => 'int8s',
        %Image::ExifTool::Exif::printParameter,
    },
    0x76 => { #15
        Name => 'Saturation',
        Format => 'int8s',
        %Image::ExifTool::Exif::printParameter,
    },
    0x77 => { #15
        Name => 'ColorTone',
        Format => 'int8s',
        %Image::ExifTool::Exif::printParameter,
    },
    0x79 => { #15
        Name => 'ISO',
        Format => 'string[5]',
    },
);

# Canon camera information for 1DmkIII and 1DSmkIII (MakerNotes tag 0x0d)
# (ref PH unless otherwise noted)
%Image::ExifTool::Canon::CameraInfo1DmkIII = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    IS_SUBDIR => [ 0x2aa ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the 1DmkIII and 1DSmkIII.',
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime }, #9
    0x06 => { %ciISO },
    0x18 => { %ciCameraTemperature }, #36
    0x1b => { %ciMacroMagnification }, #(NC)
    0x1d => { %ciFocalLength },
    0x30 => {
        Name => 'CameraOrientation', # <-- (always 9th byte after 0xbbbb for all models - Dave Coffin)
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x43 => { #21/24
        Name => 'FocusDistanceUpper',
        # (it looks like the focus distances are also odd-byte big-endian)
        %focusDistanceByteSwap,
    },
    0x45 => { #21/24
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0x5e => { #15
        Name => 'WhiteBalance',
        Format => 'int16u',
        PrintConv => \%canonWhiteBalance,
        SeparateTable => 1,
    },
    0x62 => { #15
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0x86 => {
        Name => 'PictureStyle',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0x111 => { #15
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        PrintConv => \%canonLensTypes,
    },
    0x113 => { %ciShortFocal },
    0x115 => { %ciLongFocal },
    0x136 => { #15
        Name => 'FirmwareVersion',
        Format => 'string[6]',
    },
    0x172 => {
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x176 => {
        Name => 'ShutterCount',
        Notes => 'may be valid only for some 1DmkIII copies, even running the same firmware',
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x17e => { #(NC)
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x2aa => { #48
        Name => 'PictureStyleInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::PSInfo',
        },
    },
    0x45a => { #29
        Name => 'TimeStamp1',
        Condition => '$$self{Model} =~ /\b1D Mark III$/',
        Format => 'int32u',
        Groups => { 2 => 'Time' },
        # observed in 1DmkIII firmware 5.3.1 (pre-production), 1.0.3, 1.0.8
        Notes => 'only valid for some versions of the 1DmkIII firmware',
        Shift => 'Time',
        RawConv => '$val ? $val : undef',
        ValueConv => 'ConvertUnixTime($val)',
        ValueConvInv => 'GetUnixTime($val)',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
    0x45e => {
        Name => 'TimeStamp',
        Format => 'int32u',
        Groups => { 2 => 'Time' },
        # observed in 1DmkIII firmware 1.1.0, 1.1.3 and
        # 1DSmkIII firmware 1.0.0, 1.0.4, 2.1.2, 2.7.1
        Notes => 'valid for the 1DSmkIII and some versions of the 1DmkIII firmware',
        Shift => 'Time',
        RawConv => '$val ? $val : undef',
        ValueConv => 'ConvertUnixTime($val)',
        ValueConvInv => 'GetUnixTime($val)',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
);

# Canon camera information for 1DmkIV (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo1DmkIV = (
    %binaryDataAttrs,
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    DATAMEMBER => [ 0x57 ],
    IS_SUBDIR => [ 0x363, 0x368 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the 1DmkIV.',
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime },
    0x06 => { %ciISO },
    0x07 => {
        Name => 'HighlightTonePriority',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x08 => {
        Name => 'MeasuredEV2',
        Description => 'Measured EV 2',
        RawConv => '$val ? $val : undef',
        ValueConv => '$val / 8 - 6',
        ValueConvInv => 'int(($val + 6) * 8 + 0.5)',
    },
    0x09 => {
        Name => 'MeasuredEV3',
        Description => 'Measured EV 3',
        RawConv => '$val ? $val : undef',
        ValueConv => '$val / 8 - 6',
        ValueConvInv => 'int(($val + 6) * 8 + 0.5)',
    },
    0x15 => {
        Name => 'FlashMeteringMode',
        PrintConv => {
            0 => 'E-TTL',
            3 => 'TTL',
            4 => 'External Auto',
            5 => 'External Manual',
            6 => 'Off',
        },
    },
    0x19 => { %ciCameraTemperature },
    0x1e => { %ciFocalLength },
    0x35 => {
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x54 => {
        Name => 'FocusDistanceUpper',
        %focusDistanceByteSwap,
    },
    0x56 => {
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0x57 => {
        Name => 'FirmwareVersionLookAhead',
        Hidden => 1,
        # must look ahead to check location of FirmwareVersion string
        Format => 'undef[0x1a6]',
        RawConv => q{
            my $t = substr($val, 0x1e8 - 0x57, 6);
            $t =~ /^\d+\.\d+\.\d+/ and $$self{CanonFirmA} = 1;
            $t = substr($val, 0x1ed - 0x57, 6);
            $t =~ /^\d+\.\d+\.\d+/ and $$self{CanonFirmB} = 1;
            return undef;   # not a real tag
        },
    },
    0x77 => {
        Name => 'WhiteBalance',
        Condition => '$$self{CanonFirmA}',
        Notes => 'firmware 4.2.1',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x78 => {
        Name => 'WhiteBalance',
        Condition => '$$self{CanonFirmB}',
        Notes => 'firmware 1.0.4',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x7b => {
        Name => 'ColorTemperature',
        Condition => '$$self{CanonFirmA}',
        Format => 'int16u',
    },
    0x7c => {
        Name => 'ColorTemperature',
        Condition => '$$self{CanonFirmB}',
        Format => 'int16u',
    },
    0x14e => {
        Name => 'LensType',
        Condition => '$$self{CanonFirmA}',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        PrintConv => \%canonLensTypes,
    },
    0x14f => {
        Name => 'LensType',
        Condition => '$$self{CanonFirmB}',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        PrintConv => \%canonLensTypes,
    },
    0x150 => {
        %ciShortFocal,
        Condition => '$$self{CanonFirmA}',
    },
    0x151 => {
        %ciShortFocal,
        Condition => '$$self{CanonFirmB}',
    },
    0x152 => {
        %ciLongFocal,
        Condition => '$$self{CanonFirmA}',
    },
    0x153 => {
        %ciLongFocal,
        Condition => '$$self{CanonFirmB}',
    },
    0x1e8 => { # firmware 4.2.1 (pre-production)
        Name => 'FirmwareVersion',
        Condition => '$$self{CanonFirmA}',
        Format => 'string[6]',
        Writable => 0,
    },
    0x1ed => { # firmware 1.0.4
        Name => 'FirmwareVersion',
        Condition => '$$self{CanonFirmB}',
        Format => 'string[6]',
        Writable => 0,
    },
    0x227 => { #(NC)
        Name => 'FileIndex',
        Condition => '$$self{CanonFirmA}',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x22c => { #(NC)
        Name => 'FileIndex',
        Condition => '$$self{CanonFirmB}',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x233 => { #(NC)
        Name => 'DirectoryIndex',
        Condition => '$$self{CanonFirmA}',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x238 => { #(NC)
        Name => 'DirectoryIndex',
        Condition => '$$self{CanonFirmB}',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x363 => {
        Name => 'PictureStyleInfo',
        Condition => '$$self{CanonFirmA}',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::PSInfo',
        },
    },
    0x368 => {
        Name => 'PictureStyleInfo',
        Condition => '$$self{CanonFirmB}',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::PSInfo',
        },
    },
);

# Camera information for 5D (MakerNotes tag 0x0d)
# (ref 12 unless otherwise noted)
%Image::ExifTool::Canon::CameraInfo5D = (
    %binaryDataAttrs,
    FORMAT => 'int8s',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS 5D.',
    0x03 => { %ciFNumber }, #PH
    0x04 => { %ciExposureTime }, #9
    0x06 => { %ciISO }, #PH
    0x0c => { #9
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        RawConv => '$val ? $val : undef', # don't use if value is zero
        PrintConv => \%canonLensTypes,
    },
    0x17 => { %ciCameraTemperature }, #PH
    0x1b => { %ciMacroMagnification }, #PH
    0x27 => { #PH
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x28 => { %ciFocalLength }, #15
    0x38 => {
        Name => 'AFPointsInFocus5D',
        Format => 'int16uRev',
        PrintConvColumns => 2,
        PrintConv => { BITMASK => {
            0 => 'Center',
            1 => 'Top',
            2 => 'Bottom',
            3 => 'Upper-left',
            4 => 'Upper-right',
            5 => 'Lower-left',
            6 => 'Lower-right',
            7 => 'Left',
            8 => 'Right',
            9 => 'AI Servo1',
           10 => 'AI Servo2',
           11 => 'AI Servo3',
           12 => 'AI Servo4',
           13 => 'AI Servo5',
           14 => 'AI Servo6',
        } },
    },
    0x54 => { #15
        Name => 'WhiteBalance',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x58 => { #15
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0x6c => {
        Name => 'PictureStyle',
        Format => 'int8u',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0x93 => { %ciShortFocal }, #15
    0x95 => { %ciLongFocal }, #15
    0x97 => { #15
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        PrintConv => \%canonLensTypes,
    },
    0xa4 => { #PH
        Name => 'FirmwareRevision',
        Format => 'string[8]',
    },
    0xac => { #PH
        Name => 'ShortOwnerName',
        Format => 'string[16]',
    },
    0xd0 => {
        Name => 'ImageNumber',
        Format => 'int16u',
        Groups => { 2 => 'Image' },
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0xe8 => 'ContrastStandard',
    0xe9 => 'ContrastPortrait',
    0xea => 'ContrastLandscape',
    0xeb => 'ContrastNeutral',
    0xec => 'ContrastFaithful',
    0xed => 'ContrastMonochrome',
    0xee => 'ContrastUserDef1',
    0xef => 'ContrastUserDef2',
    0xf0 => 'ContrastUserDef3',
    # sharpness values are 0-7
    0xf1 => 'SharpnessStandard',
    0xf2 => 'SharpnessPortrait',
    0xf3 => 'SharpnessLandscape',
    0xf4 => 'SharpnessNeutral',
    0xf5 => 'SharpnessFaithful',
    0xf6 => 'SharpnessMonochrome',
    0xf7 => 'SharpnessUserDef1',
    0xf8 => 'SharpnessUserDef2',
    0xf9 => 'SharpnessUserDef3',
    0xfa => 'SaturationStandard',
    0xfb => 'SaturationPortrait',
    0xfc => 'SaturationLandscape',
    0xfd => 'SaturationNeutral',
    0xfe => 'SaturationFaithful',
    0xff => {
        Name => 'FilterEffectMonochrome',
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0x100 => 'SaturationUserDef1',
    0x101 => 'SaturationUserDef2',
    0x102 => 'SaturationUserDef3',
    0x103 => 'ColorToneStandard',
    0x104 => 'ColorTonePortrait',
    0x105 => 'ColorToneLandscape',
    0x106 => 'ColorToneNeutral',
    0x107 => 'ColorToneFaithful',
    0x108 => {
        Name => 'ToningEffectMonochrome',
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0x109 => 'ColorToneUserDef1',
    0x10a => 'ColorToneUserDef2',
    0x10b => 'ColorToneUserDef3',
    0x10c => {
        Name => 'UserDef1PictureStyle',
        Format => 'int16u',
        PrintHex => 1, # (only needed for one tag)
        SeparateTable => 'UserDefStyle',
        PrintConv => \%userDefStyles,
    },
    0x10e => {
        Name => 'UserDef2PictureStyle',
        Format => 'int16u',
        SeparateTable => 'UserDefStyle',
        PrintConv => \%userDefStyles,
    },
    0x110 => {
        Name => 'UserDef3PictureStyle',
        Format => 'int16u',
        SeparateTable => 'UserDefStyle',
        PrintConv => \%userDefStyles,
    },
    0x11c => {
        Name => 'TimeStamp',
        Format => 'int32u',
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        RawConv => '$val ? $val : undef',
        ValueConv => 'ConvertUnixTime($val)',
        ValueConvInv => 'GetUnixTime($val)',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
);

# Camera information for 5D Mark II (MakerNotes tag 0x0d)
# (ref PH unless otherwise noted)
%Image::ExifTool::Canon::CameraInfo5DmkII = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    IS_SUBDIR => [ 0x15a, 0x17e ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS 5D Mark II.',
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime },
    0x06 => { %ciISO },
    0x07 => {
        Name => 'HighlightTonePriority',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x1b => { %ciMacroMagnification }, #PH
    0x15 => { #PH (580 EX II)
        Name => 'FlashMeteringMode',
        PrintConv => {
            0 => 'E-TTL',
            3 => 'TTL',
            4 => 'External Auto',
            5 => 'External Manual',
            6 => 'Off',
        },
    },
    0x19 => { %ciCameraTemperature }, #36
    # 0x1b, 0x1c, 0x1d - same as FileInfo 0x10 - PH
    0x1e => { %ciFocalLength },
    0x31 => {
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x50 => {
        Name => 'FocusDistanceUpper',
        %focusDistanceByteSwap,
    },
    0x52 => {
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0x6f => {
        Name => 'WhiteBalance',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x73 => {
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0xa7 => {
        Name => 'PictureStyle',
        Format => 'int8u',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0xbd => {
        Name => 'HighISONoiseReduction',
        PrintConv => {
            0 => 'Standard',
            1 => 'Low',
            2 => 'Strong',
            3 => 'Off',
        },
    },
    0xbf => {
        Name => 'AutoLightingOptimizer',
        PrintConv => {
            0 => 'Standard',
            1 => 'Low',
            2 => 'Strong',
            3 => 'Off',
        },
    },
    0xe6 => {
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        PrintConv => \%canonLensTypes,
    },
    0xe8 => { %ciShortFocal },
    0xea => { %ciLongFocal },
    0x15a => {
        Name => 'CameraInfo5DmkII_2a',
        Condition => '$$valPt =~ /^\d+\.\d+\.\d+[\s\0]/',
        Notes => 'at this location for firmware 3.4.6 and 3.6.1',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::CameraInfo5DmkII_2',
        },
    },
    0x17e => {
        Name => 'CameraInfo5DmkII_2b',
        Condition => '$$valPt =~ /^\d+\.\d+\.\d+[\s\0]/',
        Notes => 'at this location for firmware 1.0.6 and 4.1.1',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::CameraInfo5DmkII_2',
        },
    },
);

# variable-position Camera information for 5DmkII (ref PH)
%Image::ExifTool::Canon::CameraInfo5DmkII_2 = (
    %binaryDataAttrs,
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    IS_SUBDIR => [ 0x179 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'More CameraInfo tags for the EOS 5D Mark II.',
    0 => {
        Name => 'FirmwareVersion',
        Format => 'string[6]',
        Writable => 0, # not writable for logic reasons
        # some firmwares have a null instead of a space after the version number
        RawConv => '$val=~/^\d+\.\d+\.\d+\s*$/ ? $val : undef',
    },
    0x3d => {
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x49 => { #(NC)
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x179 => { #48
        Name => 'PictureStyleInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::PSInfo',
        },
    },
);

# Camera information for 7D (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo7D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    IS_SUBDIR => [ 0x20, 0x24 ],
    DATAMEMBER => [ 0x1f ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS 7D.',
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime },
    0x06 => { %ciISO },
    0x07 => {
        Name => 'HighlightTonePriority',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x08 => { #37
        Name => 'MeasuredEV2',
        Description => 'Measured EV 2',
        RawConv => '$val ? $val : undef',
        ValueConv => '$val / 8 - 6',
        ValueConvInv => 'int(($val + 6) * 8 + 0.5)',
    },
    0x09 => { #37
        Name => 'MeasuredEV',
        Description => 'Measured EV',
        RawConv => '$val ? $val : undef',
        ValueConv => '$val / 8 - 6',
        ValueConvInv => 'int(($val + 6) * 8 + 0.5)',
    },
    0x15 => { #PH (580 EX II)
        Name => 'FlashMeteringMode',
        PrintConv => {
            0 => 'E-TTL',
            3 => 'TTL',
            4 => 'External Auto',
            5 => 'External Manual',
            6 => 'Off',
        },
    },
    0x19 => { %ciCameraTemperature },
    0x1e => { %ciFocalLength },
    0x1f => {
        Name => 'FirmwareVersionLookAhead',
        Hidden => 1,
        # must look ahead to check location of FirmwareVersion string
        Format => 'undef[0x1a0]',
        RawConv => q{
            my $t = substr($val, 0x1a8 - 0x1f, 6);
            $t =~ /^\d+\.\d+\.\d+/ and $$self{CanonFirmA} = 1;
            $t = substr($val, 0x1ac - 0x1f, 6);
            $t =~ /^\d+\.\d+\.\d+/ and $$self{CanonFirmB} = 1;
            return undef;   # not a real tag
        },
    },
    0x20 => {
        Name => 'CameraInfo7D_2a',
        Condition => '$$self{CanonFirmA}',
        Notes => 'at this location for pre-production firmware version 3.7.5',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::CameraInfo7D_2',
        },
    },
    0x24 => {
        Name => 'CameraInfo7D_2b',
        Condition => '$$self{CanonFirmB}',
        Notes => 'at this location for firmware 1.0.7, 1.0.8, 1.1.0, 1.2.1 and 1.2.2',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::CameraInfo7D_2',
        },
    },
);

# variable-position Camera information for 7D (ref PH)
%Image::ExifTool::Canon::CameraInfo7D_2 = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    IS_SUBDIR => [ 0x303 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'More CameraInfo tags for the EOS 7D.',
    0x11 => {
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x30 => {
        Name => 'FocusDistanceUpper',
        %focusDistanceByteSwap,
    },
    0x32 => {
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0x53 => {
        Name => 'WhiteBalance',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x57 => {
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0xa5 => {
        Name => 'HighISONoiseReduction',
        PrintConv => {
            0 => 'Standard',
            1 => 'Low',
            2 => 'Strong',
            3 => 'Off',
        },
    },
    0xee => {
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        PrintConv => \%canonLensTypes,
    },
    0xf0 => { %ciShortFocal },
    0xf2 => { %ciLongFocal },
    0x188 => {
        Name => 'FirmwareVersion',
        Format => 'string[6]',
        Writable => 0, # not writable for logic reasons
        # some firmwares have a null instead of a space after the version number
        RawConv => '$val=~/^\d+\.\d+\.\d+\s*$/ ? $val : undef',
    },
    0x1c7 => {
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x1d3 => { #(NC)
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x303 => { #48
        Name => 'PictureStyleInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::PSInfo',
        },
    },
);

# Canon camera information for 40D (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo40D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    IS_SUBDIR => [ 0x25b ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS 40D.',
    0x03 => { %ciFNumber }, #PH
    0x04 => { %ciExposureTime }, #PH
    0x06 => { %ciISO }, #PH
    0x15 => { #PH (580 EX II)
        Name => 'FlashMeteringMode',
        PrintConv => {
            0 => 'E-TTL',
            3 => 'TTL',
            4 => 'External Auto',
            5 => 'External Manual',
            6 => 'Off',
        },
    },
    0x18 => { %ciCameraTemperature }, #36
    0x1b => { %ciMacroMagnification }, #PH
    0x1d => { %ciFocalLength }, #PH
    0x30 => { #20
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x43 => { #21/24
        Name => 'FocusDistanceUpper',
        # this is very odd (little-endian number on odd boundary),
        # but it does seem to work better with my sample images - PH
        %focusDistanceByteSwap,
    },
    0x45 => { #21/24
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0x6f => { #15
        Name => 'WhiteBalance',
        Format => 'int16u',
        PrintConv => \%canonWhiteBalance,
        SeparateTable => 1,
    },
    0x73 => { #15
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0xd6 => { #15
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        PrintConv => \%canonLensTypes,
    },
    0xd8 => { %ciShortFocal }, #15
    0xda => { %ciLongFocal }, #15
    0xff => { #15
        Name => 'FirmwareVersion',
        Format => 'string[6]',
    },
    0x133 => { #27
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        Notes => 'combined with DirectoryIndex to give the Composite FileNumber tag',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x13f => { #27
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1', # yes, minus (opposite to FileIndex)
        ValueConvInv => '$val + 1',
    },
    0x25b => {
        Name => 'PictureStyleInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::PSInfo',
        },
    },
    0x92b => { #33
        Name => 'LensModel',
        Format => 'string[64]',
    },
);

# Canon camera information for 50D (MakerNotes tag 0x0d)
# (ref PH unless otherwise noted)
%Image::ExifTool::Canon::CameraInfo50D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    DATAMEMBER => [ 0x15a, 0x15e ],
    IS_SUBDIR => [ 0x2d3, 0x2d7 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS 50D.',
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime },
    0x06 => { %ciISO },
    0x07 => {
        Name => 'HighlightTonePriority',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x15 => { #PH (580 EX II)
        Name => 'FlashMeteringMode',
        PrintConv => {
            0 => 'E-TTL',
            3 => 'TTL',
            4 => 'External Auto',
            5 => 'External Manual',
            6 => 'Off',
        },
    },
    0x19 => { %ciCameraTemperature }, #36
    0x1e => { %ciFocalLength },
    0x31 => {
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x50 => { #33
        Name => 'FocusDistanceUpper',
        %focusDistanceByteSwap,
    },
    0x52 => { #33
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0x6f => {
        Name => 'WhiteBalance',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x73 => { #33
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0xa7 => {
        Name => 'PictureStyle',
        Format => 'int8u',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0xbd => {
        Name => 'HighISONoiseReduction',
        PrintConv => {
            0 => 'Standard',
            1 => 'Low',
            2 => 'Strong',
            3 => 'Off',
        },
    },
    0xbf => {
        Name => 'AutoLightingOptimizer',
        PrintConv => {
            0 => 'Standard',
            1 => 'Low',
            2 => 'Strong',
            3 => 'Off',
        },
    },
    0xea => { #33
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        PrintConv => \%canonLensTypes,
    },
    0xec => { %ciShortFocal },
    0xee => { %ciLongFocal },
    0x15a => {
        Name => 'FirmwareVersion',
        Format => 'string[6]',
        Notes => 'at this location for firmware 2.6.1',
        Writable => 0,
        RawConv => '$val=~/^\d+\.\d+\.\d+\s*$/ ? $$self{CanonFirmA}=$val : undef',
    },
    0x15e => { #33
        Name => 'FirmwareVersion',
        Format => 'string[6]',
        Notes => 'at this location for firmware 1.0.2, 1.0.3, 2.9.1 and 3.1.1',
        Writable => 0,
        RawConv => '$val=~/^\d+\.\d+\.\d+\s*$/ ? $$self{CanonFirmB}=$val : undef',
    },
    0x197 => {
        Name => 'FileIndex',
        Condition => '$$self{CanonFirmA}',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x19b => {
        Name => 'FileIndex',
        Condition => '$$self{CanonFirmB}',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x1a3 => { #(NC)
        Name => 'DirectoryIndex',
        Condition => '$$self{CanonFirmA}',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x1a7 => { #(NC)
        Name => 'DirectoryIndex',
        Condition => '$$self{CanonFirmB}',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x2d3 => {
        Name => 'PictureStyleInfo',
        Condition => '$$self{CanonFirmA}',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::PSInfo',
        },
    },
    0x2d7 => {
        Name => 'PictureStyleInfo',
        Condition => '$$self{CanonFirmB}',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::PSInfo',
        },
    },
);

# Canon camera information for 60D (MakerNotes tag 0x0d)
# (ref PH unless otherwise noted)
# NOTE: Can probably borrow more 50D tags here, possibly with an offset
%Image::ExifTool::Canon::CameraInfo60D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
  #  DATAMEMBER => [ 0x199 ],
    IS_SUBDIR => [ 0x321 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS 60D.',
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime },
    0x06 => { %ciISO },
    0x19 => { %ciCameraTemperature },
    0x1e => { %ciFocalLength },
    0x36 => {
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x55 => {
        Name => 'FocusDistanceUpper',
        %focusDistanceByteSwap,
    },
    0x57 => {
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0x7d => {
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0xe8 => {
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        PrintConv => \%canonLensTypes,
    },
    0xea => { %ciShortFocal },
    0xec => { %ciLongFocal },
    0x199 => {
        Name => 'FirmwareVersion',
        Format => 'string[6]',
  #      Notes => 'at this location for firmware 2.8.1 and 1.0.5',
        Writable => 0,
  #      RawConv => '$val=~/^\d+\.\d+\.\d+\s*$/ ? $$self{CanonFirmA}=$val : undef',
    },
    0x1d9 => {
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x1e5 => { #(NC)
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x321 => {
        Name => 'PictureStyleInfo2',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::PSInfo2',
        },
    },
);

# Canon camera information for 450D (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo450D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    IS_SUBDIR => [ 0x263 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS 450D.',
    0x03 => { %ciFNumber }, #PH
    0x04 => { %ciExposureTime }, #PH
    0x06 => { %ciISO }, #PH
    0x15 => { #PH (580 EX II)
        Name => 'FlashMeteringMode',
        PrintConv => {
            0 => 'E-TTL',
            3 => 'TTL',
            4 => 'External Auto',
            5 => 'External Manual',
            6 => 'Off',
        },
    },
    0x18 => { %ciCameraTemperature }, #36
    0x1b => { %ciMacroMagnification }, #PH
    0x1d => { %ciFocalLength }, #PH
    0x30 => { #20
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x43 => { #20
        Name => 'FocusDistanceUpper',
        # this is very odd (little-endian number on odd boundary),
        # but it does seem to work better with my sample images - PH
        %focusDistanceByteSwap,
    },
    0x45 => { #20
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0x6f => { #PH
        Name => 'WhiteBalance',
        Format => 'int16u',
        PrintConv => \%canonWhiteBalance,
        SeparateTable => 1,
    },
    0x73 => { #PH
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0xde => { #33
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        PrintConv => \%canonLensTypes,
    },
    0x107 => { #PH
        Name => 'FirmwareVersion',
        Format => 'string[6]',
    },
    0x10f => { #20
        Name => 'OwnerName',
        Format => 'string[32]',
    },
    0x133 => { #20
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
    },
    0x13f => { #20
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x263 => { #PH
        Name => 'PictureStyleInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::PSInfo',
        },
    },
    0x933 => { #33
        Name => 'LensModel',
        Format => 'string[64]',
    },
);

# Canon camera information for 500D (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo500D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    IS_SUBDIR => [ 0x30b ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS 500D.',
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime },
    0x06 => { %ciISO },
    0x07 => {
        Name => 'HighlightTonePriority',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x15 => { #PH (580 EX II)
        Name => 'FlashMeteringMode',
        PrintConv => {
            0 => 'E-TTL',
            3 => 'TTL',
            4 => 'External Auto',
            5 => 'External Manual',
            6 => 'Off',
        },
    },
    0x19 => { %ciCameraTemperature },
    0x1e => { %ciFocalLength },
    0x31 => {
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x50 => {
        Name => 'FocusDistanceUpper',
        %focusDistanceByteSwap,
    },
    0x52 => {
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0x73 => { # (50D + 4)
        Name => 'WhiteBalance',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x77 => { # (50D + 4)
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0xab => { # (50D + 4)
        Name => 'PictureStyle',
        Format => 'int8u',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0xbc => {
        Name => 'HighISONoiseReduction',
        PrintConv => {
            0 => 'Standard',
            1 => 'Low',
            2 => 'Strong',
            3 => 'Off',
        },
    },
    0xbe => {
        Name => 'AutoLightingOptimizer',
        PrintConv => {
            0 => 'Standard',
            1 => 'Low',
            2 => 'Strong',
            3 => 'Off',
        },
    },
    0xf6 => {
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        PrintConv => \%canonLensTypes,
    },
    0xf8 => { %ciShortFocal },
    0xfa => { %ciLongFocal },
    0x190 => {
        Name => 'FirmwareVersion',
        Format => 'string[6]',
        Writable => 0,
        RawConv => '$val=~/^\d+\.\d+\.\d+\s*$/ ? $val : undef',
    },
    0x1d3 => {
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x1df => { #(NC)
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x30b => {
        Name => 'PictureStyleInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::PSInfo',
        },
    },
);

# Canon camera information for 550D (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo550D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    IS_SUBDIR => [ 0x31c ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS 550D.',
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime },
    0x06 => { %ciISO },
    0x07 => { #(NC)
        Name => 'HighlightTonePriority',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x15 => { #(NC)
        Name => 'FlashMeteringMode',
        PrintConv => {
            0 => 'E-TTL',
            3 => 'TTL',
            4 => 'External Auto',
            5 => 'External Manual',
            6 => 'Off',
        },
    },
    0x19 => { %ciCameraTemperature }, # (500D + 0)
    0x1e => { %ciFocalLength }, # (500D + 0)
    0x35 => { # (500D + 4)
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x54 => { # (500D + 4)
        Name => 'FocusDistanceUpper',
        %focusDistanceByteSwap,
    },
    0x56 => { # (500D + 4)
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0x78 => { # (500D + 5) (NC)
        Name => 'WhiteBalance',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x7c => { # (500D + 5)
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0xb0 => { # (500D + 5)
        Name => 'PictureStyle',
        Format => 'int8u',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0xff => { # (500D + 9)
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        PrintConv => \%canonLensTypes,
    },
    0x101 => { %ciShortFocal }, # (500D + 9)
    0x103 => { %ciLongFocal }, # (500D + 9)
    0x1a4 => { # (500D + 0x11)
        Name => 'FirmwareVersion',
        Format => 'string[6]',
        Writable => 0,
        RawConv => '$val=~/^\d+\.\d+\.\d+\s*$/ ? $val : undef',
    },
    0x1e4 => { # (500D + 0x11)
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x1f0 => { # (500D + 0x11) (NC)
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x31c => { #48
        Name => 'PictureStyleInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::PSInfo',
        },
    },
);

# Canon camera information for 1000D (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo1000D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    IS_SUBDIR => [ 0x267 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS 1000D.',
    0x03 => { %ciFNumber }, #PH
    0x04 => { %ciExposureTime }, #PH
    0x06 => { %ciISO }, #PH
    0x15 => { #PH (580 EX II)
        Name => 'FlashMeteringMode',
        PrintConv => {
            0 => 'E-TTL',
            3 => 'TTL',
            4 => 'External Auto',
            5 => 'External Manual',
            6 => 'Off',
        },
    },
    0x18 => { %ciCameraTemperature }, #36
    0x1b => { %ciMacroMagnification }, #PH (NC)
    0x1d => { %ciFocalLength }, #PH
    0x30 => { #20
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x43 => { #20
        Name => 'FocusDistanceUpper',
        %focusDistanceByteSwap,
    },
    0x45 => { #20
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0x6f => { #PH
        Name => 'WhiteBalance',
        Format => 'int16u',
        PrintConv => \%canonWhiteBalance,
        SeparateTable => 1,
    },
    0x73 => { #PH
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0xe2 => { #PH
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        PrintConv => \%canonLensTypes,
    },
    0x10b => { #PH
        Name => 'FirmwareVersion',
        Format => 'string[6]',
    },
    0x137 => { #PH (NC)
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
    },
    0x143 => { #PH
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x267 => { #PH
        Name => 'PictureStyleInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::PSInfo',
        },
    },
    0x937 => { #PH
        Name => 'LensModel',
        Format => 'string[64]',
    },
);

# Canon camera information for PowerShot models (MakerNotes tag 0x0d) - PH
%Image::ExifTool::Canon::CameraInfoPowerShot = (
    %binaryDataAttrs,
    FORMAT => 'int32s',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        CameraInfo tags for PowerShot models such as the A450, A460, A550, A560,
        A570, A630, A640, A650, A710, A720, G7, G9, S5, SD40, SD750, SD800, SD850,
        SD870, SD900, SD950, SD1000, SX100 and TX1.
    },
    0x00 => {
        Name => 'ISO',
        Groups => { 2 => 'Image' },
        ValueConv => '100*exp((($val-411)/96)*log(2))',
        ValueConvInv => 'log($val/100)/log(2)*96+411',
        PrintConv => 'sprintf("%.0f",$val)',
        PrintConvInv => '$val',
    },
    0x05 => {
        Name => 'FNumber',
        Groups => { 2 => 'Image' },
        ValueConv => 'exp($val/192*log(2))',
        ValueConvInv => 'log($val)*192/log(2)',
        PrintConv => 'sprintf("%.2g",$val)',
        PrintConvInv => '$val',
    },
    0x06 => {
        Name => 'ExposureTime',
        Groups => { 2 => 'Image' },
        ValueConv => 'exp(-$val/96*log(2))',
        ValueConvInv => '-log($val)*96/log(2)',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x17 => 'Rotation', # usually the same as Orientation (but not always! why?)
    # 0x25 - flash fired/not fired (ref 37)
    # 0x26 - related to flash mode? (ref 37)
    # 0x37 - related to flash strength (ref 37)
    # 0x38 - pre-flash fired/no fired or flash data collection (ref 37)
    135 => { # [-3] <-- index relative to CameraInfoCount
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 138',
        Notes => 'A450, A460, A550, A630, A640 and A710',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    145 => { #37 [-3]
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 148',
        Notes => q{
            A560, A570, A650, A720, G7, G9, S5, SD40, SD750, SD800, SD850, SD870, SD900,
            SD950, SD1000, SX100 and TX1
        },
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
);

# Canon camera information for some PowerShot models (MakerNotes tag 0x0d) - PH
%Image::ExifTool::Canon::CameraInfoPowerShot2 = (
    %binaryDataAttrs,
    FORMAT => 'int32s',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        CameraInfo tags for PowerShot models such as the A470, A480, A490, A495,
        A580, A590, A1000, A1100, A2000, A2100, A3000, A3100, D10, E1, G10, G11,
        S90, S95, SD770, SD780, SD790, SD880, SD890, SD940, SD960, SD970, SD980,
        SD990, SD1100, SD1200, SD1300, SD1400, SD3500, SD4000, SD4500, SX1, SX10,
        SX20, SX110, SX120, SX130, SX200 and SX210.
    },
    0x01 => {
        Name => 'ISO',
        Groups => { 2 => 'Image' },
        ValueConv => '100*exp((($val-411)/96)*log(2))',
        ValueConvInv => 'log($val/100)/log(2)*96+411',
        PrintConv => 'sprintf("%.0f",$val)',
        PrintConvInv => '$val',
    },
    0x06 => {
        Name => 'FNumber',
        Groups => { 2 => 'Image' },
        ValueConv => 'exp($val/192*log(2))',
        ValueConvInv => 'log($val)*192/log(2)',
        PrintConv => 'sprintf("%.2g",$val)',
        PrintConvInv => '$val',
    },
    0x07 => {
        Name => 'ExposureTime',
        Groups => { 2 => 'Image' },
        ValueConv => 'exp(-$val/96*log(2))',
        ValueConvInv => '-log($val)*96/log(2)',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x18 => 'Rotation',
    153 => { # [-3] <-- index relative to CameraInfoCount
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 156',
        Notes => 'A470, A580, A590, SD770, SD790, SD890 and SD1100',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    159 => { # [-3]
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 162',
        Notes => 'A1000, A2000, E1, G10, SD880, SD990, SX1, SX10 and SX110',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    164 => { # [-3]
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 167',
        Notes => 'A480, A1100, A2100, D10, SD780, SD960, SD970, SD1200 and SX200',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    168 => { # [-3]
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 171',
        Notes => q{
            A490, A495, A3000, A3100, G11, S90, SD940, SD980, SD1300, SD1400, SD3500,
            SD4000, SX20, SX120 and SX210
        },
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    261 => { # [-3]
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 264',
        Notes => 'S95, SD4500 and SX130',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
);

# unknown Canon camera information (MakerNotes tag 0x0d) - PH
%Image::ExifTool::Canon::CameraInfoUnknown32 = (
    %binaryDataAttrs,
    FORMAT => 'int32s',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Unknown CameraInfo tags are divided into 3 tables based on format size.',
    71 => { # [-1] <-- index relative to CameraInfoCount
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 72',
        Notes => 'S1',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    83 => { # [-2]
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 85',
        Notes => 'S2',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    91 => { # [-2 or -3]
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 93 or $$self{CameraInfoCount} == 94',
        Notes => 'A410, A610, A620, S80, SD30, SD400, SD430, SD450, SD500 and SD550',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    92 => { # [-4]
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 96',
        Notes => 'S3',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    100 => { # [-4]
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 104',
        Notes => 'A420, A430, A530, A540, A700, SD600, SD630 and SD700',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    466 => { # [-3]
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 469',
        Notes => 'A1200, A2200, A3200, A3300, 100HS, 300HS and 500HS',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    503 => { # [-3]
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 506',
        Notes => 'A800',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    506 => { # [-3]
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 509',
        Notes => 'SX230HS',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
);

# unknown Canon camera information (MakerNotes tag 0x0d) - PH
%Image::ExifTool::Canon::CameraInfoUnknown16 = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
);

# unknown Canon camera information (MakerNotes tag 0x0d) - PH
%Image::ExifTool::Canon::CameraInfoUnknown = (
    %binaryDataAttrs,
    FORMAT => 'int8s',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
);

# Picture Style information for various cameras (ref 48)
%Image::ExifTool::Canon::PSInfo = (
    %binaryDataAttrs,
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom picture style information for various models.',
    # (values expected to be "n/a" are flagged as Unknown)
    0x00 => { Name => 'ContrastStandard',      %psInfo },
    0x04 => { Name => 'SharpnessStandard',     %psInfo },
    0x08 => { Name => 'SaturationStandard',    %psInfo },
    0x0c => { Name => 'ColorToneStandard',     %psInfo },
    0x10 => { Name => 'FilterEffectStandard',  %psInfo, Unknown => 1 },
    0x14 => { Name => 'ToningEffectStandard',  %psInfo, Unknown => 1 },
    0x18 => { Name => 'ContrastPortrait',      %psInfo },
    0x1c => { Name => 'SharpnessPortrait',     %psInfo },
    0x20 => { Name => 'SaturationPortrait',    %psInfo },
    0x24 => { Name => 'ColorTonePortrait',     %psInfo },
    0x28 => { Name => 'FilterEffectPortrait',  %psInfo, Unknown => 1 },
    0x2c => { Name => 'ToningEffectPortrait',  %psInfo, Unknown => 1 },
    0x30 => { Name => 'ContrastLandscape',     %psInfo },
    0x34 => { Name => 'SharpnessLandscape',    %psInfo },
    0x38 => { Name => 'SaturationLandscape',   %psInfo },
    0x3c => { Name => 'ColorToneLandscape',    %psInfo },
    0x40 => { Name => 'FilterEffectLandscape', %psInfo, Unknown => 1 },
    0x44 => { Name => 'ToningEffectLandscape', %psInfo, Unknown => 1 },
    0x48 => { Name => 'ContrastNeutral',       %psInfo },
    0x4c => { Name => 'SharpnessNeutral',      %psInfo },
    0x50 => { Name => 'SaturationNeutral',     %psInfo },
    0x54 => { Name => 'ColorToneNeutral',      %psInfo },
    0x58 => { Name => 'FilterEffectNeutral',   %psInfo, Unknown => 1 },
    0x5c => { Name => 'ToningEffectNeutral',   %psInfo, Unknown => 1 },
    0x60 => { Name => 'ContrastFaithful',      %psInfo },
    0x64 => { Name => 'SharpnessFaithful',     %psInfo },
    0x68 => { Name => 'SaturationFaithful',    %psInfo },
    0x6c => { Name => 'ColorToneFaithful',     %psInfo },
    0x70 => { Name => 'FilterEffectFaithful',  %psInfo, Unknown => 1 },
    0x74 => { Name => 'ToningEffectFaithful',  %psInfo, Unknown => 1 },
    0x78 => { Name => 'ContrastMonochrome',    %psInfo },
    0x7c => { Name => 'SharpnessMonochrome',   %psInfo },
    0x80 => { Name => 'SaturationMonochrome',  %psInfo, Unknown => 1 },
    0x84 => { Name => 'ColorToneMonochrome',   %psInfo, Unknown => 1 },
    0x88 => { Name => 'FilterEffectMonochrome',%psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0x8c => { Name => 'ToningEffectMonochrome',%psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0x90 => { Name => 'ContrastUserDef1',      %psInfo },
    0x94 => { Name => 'SharpnessUserDef1',     %psInfo },
    0x98 => { Name => 'SaturationUserDef1',    %psInfo },
    0x9c => { Name => 'ColorToneUserDef1',     %psInfo },
    0xa0 => { Name => 'FilterEffectUserDef1',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xa4 => { Name => 'ToningEffectUserDef1',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xa8 => { Name => 'ContrastUserDef2',      %psInfo },
    0xac => { Name => 'SharpnessUserDef2',     %psInfo },
    0xb0 => { Name => 'SaturationUserDef2',    %psInfo },
    0xb4 => { Name => 'ColorToneUserDef2',     %psInfo },
    0xb8 => { Name => 'FilterEffectUserDef2',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xbc => { Name => 'ToningEffectUserDef2',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xc0 => { Name => 'ContrastUserDef3',      %psInfo },
    0xc4 => { Name => 'SharpnessUserDef3',     %psInfo },
    0xc8 => { Name => 'SaturationUserDef3',    %psInfo },
    0xcc => { Name => 'ColorToneUserDef3',     %psInfo },
    0xd0 => { Name => 'FilterEffectUserDef3',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xd4 => { Name => 'ToningEffectUserDef3',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    # base picture style names:
    0xd8 => {
        Name => 'UserDef1PictureStyle',
        Format => 'int16u',
        SeparateTable => 'UserDefStyle',
        PrintConv => \%userDefStyles,
    },
    0xda => {
        Name => 'UserDef2PictureStyle',
        Format => 'int16u',
        SeparateTable => 'UserDefStyle',
        PrintConv => \%userDefStyles,
    },
    0xdc => {
        Name => 'UserDef3PictureStyle',
        Format => 'int16u',
        SeparateTable => 'UserDefStyle',
        PrintConv => \%userDefStyles,
    },
);

# Picture Style information for the 60D (ref 48)
%Image::ExifTool::Canon::PSInfo2 = (
    %binaryDataAttrs,
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom picture style information for the EOS 60D.',
    # (values expected to be "n/a" are flagged as Unknown)
    0x00 => { Name => 'ContrastStandard',      %psInfo },
    0x04 => { Name => 'SharpnessStandard',     %psInfo },
    0x08 => { Name => 'SaturationStandard',    %psInfo },
    0x0c => { Name => 'ColorToneStandard',     %psInfo },
    0x10 => { Name => 'FilterEffectStandard',  %psInfo, Unknown => 1 },
    0x14 => { Name => 'ToningEffectStandard',  %psInfo, Unknown => 1 },
    0x18 => { Name => 'ContrastPortrait',      %psInfo },
    0x1c => { Name => 'SharpnessPortrait',     %psInfo },
    0x20 => { Name => 'SaturationPortrait',    %psInfo },
    0x24 => { Name => 'ColorTonePortrait',     %psInfo },
    0x28 => { Name => 'FilterEffectPortrait',  %psInfo, Unknown => 1 },
    0x2c => { Name => 'ToningEffectPortrait',  %psInfo, Unknown => 1 },
    0x30 => { Name => 'ContrastLandscape',     %psInfo },
    0x34 => { Name => 'SharpnessLandscape',    %psInfo },
    0x38 => { Name => 'SaturationLandscape',   %psInfo },
    0x3c => { Name => 'ColorToneLandscape',    %psInfo },
    0x40 => { Name => 'FilterEffectLandscape', %psInfo, Unknown => 1 },
    0x44 => { Name => 'ToningEffectLandscape', %psInfo, Unknown => 1 },
    0x48 => { Name => 'ContrastNeutral',       %psInfo },
    0x4c => { Name => 'SharpnessNeutral',      %psInfo },
    0x50 => { Name => 'SaturationNeutral',     %psInfo },
    0x54 => { Name => 'ColorToneNeutral',      %psInfo },
    0x58 => { Name => 'FilterEffectNeutral',   %psInfo, Unknown => 1 },
    0x5c => { Name => 'ToningEffectNeutral',   %psInfo, Unknown => 1 },
    0x60 => { Name => 'ContrastFaithful',      %psInfo },
    0x64 => { Name => 'SharpnessFaithful',     %psInfo },
    0x68 => { Name => 'SaturationFaithful',    %psInfo },
    0x6c => { Name => 'ColorToneFaithful',     %psInfo },
    0x70 => { Name => 'FilterEffectFaithful',  %psInfo, Unknown => 1 },
    0x74 => { Name => 'ToningEffectFaithful',  %psInfo, Unknown => 1 },
    0x78 => { Name => 'ContrastMonochrome',    %psInfo },
    0x7c => { Name => 'SharpnessMonochrome',   %psInfo },
    0x80 => { Name => 'SaturationMonochrome',  %psInfo, Unknown => 1 },
    0x84 => { Name => 'ColorToneMonochrome',   %psInfo, Unknown => 1 },
    0x88 => { Name => 'FilterEffectMonochrome',%psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0x8c => { Name => 'ToningEffectMonochrome',%psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0x90 => { Name => 'ContrastUnknown',        %psInfo, Unknown => 1 },
    0x94 => { Name => 'SharpnessUnknown',       %psInfo, Unknown => 1 },
    0x98 => { Name => 'SaturationUnknown',      %psInfo, Unknown => 1 },
    0x9c => { Name => 'ColorToneUnknown',       %psInfo, Unknown => 1 },
    0xa0 => { Name => 'FilterEffectUnknown',    %psInfo, Unknown => 1,
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xa4 => { Name => 'ToningEffectUnknown',    %psInfo, Unknown => 1,
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xa8 => { Name => 'ContrastUserDef1',      %psInfo },
    0xac => { Name => 'SharpnessUserDef1',     %psInfo },
    0xb0 => { Name => 'SaturationUserDef1',    %psInfo },
    0xb4 => { Name => 'ColorToneUserDef1',     %psInfo },
    0xb8 => { Name => 'FilterEffectUserDef1',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xbc => { Name => 'ToningEffectUserDef1',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xc0 => { Name => 'ContrastUserDef2',      %psInfo },
    0xc4 => { Name => 'SharpnessUserDef2',     %psInfo },
    0xc8 => { Name => 'SaturationUserDef2',    %psInfo },
    0xcc => { Name => 'ColorToneUserDef2',     %psInfo },
    0xd0 => { Name => 'FilterEffectUserDef2',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xd4 => { Name => 'ToningEffectUserDef2',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xd8 => { Name => 'ContrastUserDef3',      %psInfo },
    0xdc => { Name => 'SharpnessUserDef3',     %psInfo },
    0xe0 => { Name => 'SaturationUserDef3',    %psInfo },
    0xe4 => { Name => 'ColorToneUserDef3',     %psInfo },
    0xe8 => { Name => 'FilterEffectUserDef3',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xec => { Name => 'ToningEffectUserDef3',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    # base picture style names:
    0xf0 => {
        Name => 'UserDef1PictureStyle',
        Format => 'int16u',
        SeparateTable => 'UserDefStyle',
        PrintConv => \%userDefStyles,
    },
    0xf2 => {
        Name => 'UserDef2PictureStyle',
        Format => 'int16u',
        SeparateTable => 'UserDefStyle',
        PrintConv => \%userDefStyles,
    },
    0xf4 => {
        Name => 'UserDef3PictureStyle',
        Format => 'int16u',
        SeparateTable => 'UserDefStyle',
        PrintConv => \%userDefStyles,
    },
);

# Movie information (MakerNotes tag 0x11) (ref PH)
%Image::ExifTool::Canon::MovieInfo = (
    %binaryDataAttrs,
    FORMAT => 'int16u',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Video' },
    NOTES => 'Tags written by some Canon cameras when recording video.',
    1 => { # (older PowerShot AVI)
        Name => 'FrameRate',
        RawConv => '$val == 65535 ? undef: $val',
        ValueConvInv => '$val > 65535 ? 65535 : $val',
    },
    2 => { # (older PowerShot AVI)
        Name => 'FrameCount',
        RawConv => '$val == 65535 ? undef: $val',
        ValueConvInv => '$val > 65535 ? 65535 : $val',
    },
    # 3 - values: 0x0001 (older PowerShot AVI), 0x4004, 0x4005
    4 => {
        Name => 'FrameCount',
        Format => 'int32u',
    },
    6 => {
        Name => 'FrameRate',
        Format => 'rational32u',
        PrintConv => 'int($val * 1000 + 0.5) / 1000',
        PrintConvInv => '$val',
    },
    # 9/10 - same as 6/7 (FrameRate)
    106 => {
        Name => 'Duration',
        Format => 'int32u',
        ValueConv => '$val / 1000',
        ValueConvInv => '$val * 1000',
        PrintConv => 'ConvertDuration($val)',
        PrintConvInv => q{
            my @a = ($val =~ /\d+(?:\.\d*)?/g);
            $val  = pop(@a) || 0;         # seconds
            $val += pop(@a) *   60 if @a; # minutes
            $val += pop(@a) * 3600 if @a; # hours
            return $val;
        },
    },
    108 => {
        Name => 'AudioBitrate',
        Groups => { 2 => 'Audio' },
        Format => 'int32u',
        PrintConv => 'ConvertBitrate($val)',
        PrintConvInv => q{
            $val =~ /^(\d+(?:\.\d*)?) ?([kMG]?bps)?$/ or return undef;
            return $1 * {bps=>1,kbps=>1000,Mbps=>1000000,Gbps=>1000000000}->{$2 || 'bps'};
        },
    },
    110 => {
        Name => 'AudioSampleRate',
        Groups => { 2 => 'Audio' },
        Format => 'int32u',
    },
    112 => { # (guess)
        Name => 'AudioChannels',
        Groups => { 2 => 'Audio' },
        Format => 'int32u',
    },
    # 114 - values: 0 (60D), 1 (S95)
    116 => {
        Name => 'VideoCodec',
        Format => 'undef[4]',
        # swap bytes if little endian
        RawConv => 'GetByteOrder() eq "MM" ? $val : pack("N",unpack("V",$val))',
        RawConvInv => 'GetByteOrder() eq "MM" ? $val : pack("N",unpack("V",$val))',
    },
    # 125 - same as 10
);

# AF information (MakerNotes tag 0x12) - PH
%Image::ExifTool::Canon::AFInfo = (
    PROCESS_PROC => \&ProcessSerialData,
    VARS => { ID_LABEL => 'Sequence' },
    FORMAT => 'int16u',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        Auto-focus information used by many older Canon models.  The values in this
        record are sequential, and some have variable sizes based on the value of
        NumAFPoints (which may be 1,5,7,9,15,45 or 53).  The AFArea coordinates are
        given in a system where the image has dimensions given by AFImageWidth and
        AFImageHeight, and 0,0 is the image center. The direction of the Y axis
        depends on the camera model, with positive Y upwards for EOS models, but
        apparently downwards for PowerShot models.
    },
    0 => {
        Name => 'NumAFPoints',
    },
    1 => {
        Name => 'ValidAFPoints',
        Notes => 'number of AF points valid in the following information',
    },
    2 => {
        Name => 'CanonImageWidth',
        Groups => { 2 => 'Image' },
    },
    3 => {
        Name => 'CanonImageHeight',
        Groups => { 2 => 'Image' },
    },
    4 => {
        Name => 'AFImageWidth',
        Notes => 'size of image in AF coordinates',
    },
    5 => 'AFImageHeight',
    6 => 'AFAreaWidth',
    7 => 'AFAreaHeight',
    8 => {
        Name => 'AFAreaXPositions',
        Format => 'int16s[$val{0}]',
    },
    9 => {
        Name => 'AFAreaYPositions',
        Format => 'int16s[$val{0}]',
    },
    10 => {
        Name => 'AFPointsInFocus',
        Format => 'int16s[int(($val{0}+15)/16)]',
        PrintConv => 'Image::ExifTool::DecodeBits($val, undef, 16)',
    },
    11 => [
        {
            Name => 'PrimaryAFPoint',
            Condition => q{
                $$self{Model} !~ /EOS/ and
                (not $$self{AFInfoCount} or $$self{AFInfoCount} != 36)
            },
        },
        {
            # (some PowerShot 9-point systems put PrimaryAFPoint after 8 unknown values)
            Name => 'Canon_AFInfo_0x000b',
            Condition => '$$self{Model} !~ /EOS/',
            Format => 'int16u[8]',
            Unknown => 1,
        },
        # (serial processing stops here for EOS cameras)
    ],
    12 => 'PrimaryAFPoint',
);

# newer AF information (MakerNotes tag 0x26) - PH (A570IS,1DmkIII,40D)
# (Note: this tag is out of sequence in A570IS maker notes)
%Image::ExifTool::Canon::AFInfo2 = (
    PROCESS_PROC => \&ProcessSerialData,
    VARS => { ID_LABEL => 'Sequence' },
    FORMAT => 'int16u',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        Newer version of the AFInfo record containing much of the same information
        (and coordinate confusion) as the older version.  In this record, values of
        9 and 45 have been observed for NumAFPoints.
    },
    0 => {
        Name => 'AFInfoSize',
        Unknown => 1, # normally don't print this out
    },
    1 => {
        Name => 'AFAreaMode',
        PrintConv => {
            0 => 'Off (Manual Focus)',
            2 => 'Single-point AF',
            4 => 'Multi-point AF or AI AF', # AiAF on A570IS
            5 => 'Face Detect AF',
            7 => 'Zone AF', #46
            8 => 'AF Point Expansion', #46
            9 => 'Spot AF', #46
        },
    },
    2 => {
        Name => 'NumAFPoints',
        RawConv => '$$self{NumAFPoints} = $val', # save for later
    },
    3 => {
        Name => 'ValidAFPoints',
        Notes => 'number of AF points valid in the following information',
    },
    4 => {
        Name => 'CanonImageWidth',
        Groups => { 2 => 'Image' },
    },
    5 => {
        Name => 'CanonImageHeight',
        Groups => { 2 => 'Image' },
    },
    6 => {
        Name => 'AFImageWidth',
        Notes => 'size of image in AF coordinates',
    },
    7 => 'AFImageHeight',
    8 => {
        Name => 'AFAreaWidths',
        Format => 'int16s[$val{2}]',
    },
    9 => {
        Name => 'AFAreaHeights',
        Format => 'int16s[$val{2}]',
    },
    10 => {
        Name => 'AFAreaXPositions',
        Format => 'int16s[$val{2}]',
    },
    11 => {
        Name => 'AFAreaYPositions',
        Format => 'int16s[$val{2}]',
    },
    12 => {
        Name => 'AFPointsInFocus',
        Format => 'int16s[int(($val{2}+15)/16)]',
        PrintConv => 'Image::ExifTool::DecodeBits($val, undef, 16)',
    },
    13 => [
        {
            Name => 'AFPointsSelected',
            Condition => '$$self{Model} =~ /EOS/',
            Format => 'int16s[int(($val{2}+15)/16)]',
            PrintConv => 'Image::ExifTool::DecodeBits($val, undef, 16)',
        },
        {
            Name => 'Canon_AFInfo2_0x000d',
            Format => 'int16s[int(($val{2}+15)/16)+1]',
            Unknown => 1,
        },
    ],
    14 => {
        # usually, but not always, the lowest number AF point in focus
        Name => 'PrimaryAFPoint',
        Condition => '$$self{Model} !~ /EOS/',
    },
);

# my color mode information (MakerNotes tag 0x1d) - PH (A570IS)
%Image::ExifTool::Canon::MyColors = (
    %binaryDataAttrs,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x02 => {
        Name => 'MyColorMode',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Off',
            1 => 'Positive Film', #15 (SD600)
            2 => 'Light Skin Tone', #15
            3 => 'Dark Skin Tone', #15
            4 => 'Vivid Blue', #15
            5 => 'Vivid Green', #15
            6 => 'Vivid Red', #15
            7 => 'Color Accent', #15 (A610) (NC)
            8 => 'Color Swap', #15 (A610)
            9 => 'Custom',
            12 => 'Vivid',
            13 => 'Neutral',
            14 => 'Sepia',
            15 => 'B&W',
        },
    },
);

# face detect information (MakerNotes tag 0x24) - PH (A570IS)
%Image::ExifTool::Canon::FaceDetect1 = (
    %binaryDataAttrs,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    DATAMEMBER => [ 0x02 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x02 => {
        Name => 'FacesDetected',
        DataMember => 'FacesDetected',
        RawConv => '$$self{FacesDetected} = $val',
    },
    0x03 => {
        Name => 'FaceDetectFrameSize',
        Format => 'int16u[2]',
    },
    0x08 => {
        Name => 'Face1Position',
        Format => 'int16s[2]',
        RawConv => '$$self{FacesDetected} < 1 ? undef: $val',
        Notes => q{
            X-Y coordinates for the center of each face in the Face Detect frame at the
            time of focus lock. "0 0" is the center, and positive X and Y are to the
            right and downwards respectively
        },
    },
    0x0a => {
        Name => 'Face2Position',
        Format => 'int16s[2]',
        RawConv => '$$self{FacesDetected} < 2 ? undef : $val',
    },
    0x0c => {
        Name => 'Face3Position',
        Format => 'int16s[2]',
        RawConv => '$$self{FacesDetected} < 3 ? undef : $val',
    },
    0x0e => {
        Name => 'Face4Position',
        Format => 'int16s[2]',
        RawConv => '$$self{FacesDetected} < 4 ? undef : $val',
    },
    0x10 => {
        Name => 'Face5Position',
        Format => 'int16s[2]',
        RawConv => '$$self{FacesDetected} < 5 ? undef : $val',
    },
    0x12 => {
        Name => 'Face6Position',
        Format => 'int16s[2]',
        RawConv => '$$self{FacesDetected} < 6 ? undef : $val',
    },
    0x14 => {
        Name => 'Face7Position',
        Format => 'int16s[2]',
        RawConv => '$$self{FacesDetected} < 7 ? undef : $val',
    },
    0x16 => {
        Name => 'Face8Position',
        Format => 'int16s[2]',
        RawConv => '$$self{FacesDetected} < 8 ? undef : $val',
    },
    0x18 => {
        Name => 'Face9Position',
        Format => 'int16s[2]',
        RawConv => '$$self{FacesDetected} < 9 ? undef : $val',
    },
);

# more face detect information (MakerNotes tag 0x25) - PH (A570IS)
%Image::ExifTool::Canon::FaceDetect2 = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x01 => 'FaceWidth',
    0x02 => 'FacesDetected',
);

# File number information (MakerNotes tag 0x93)
%Image::ExifTool::Canon::FileInfo = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    1 => [
        { #5
            Name => 'FileNumber',
            Condition => '$$self{Model} =~ /\b(20D|350D|REBEL XT|Kiss Digital N)\b/',
            Format => 'int32u',
            # Thanks to Juha Eskelinen for figuring this out:
            # [this is an odd bit mapping -- it looks like the file number exists as
            # a 16-bit integer containing the high bits, followed by an 8-bit integer
            # with the low bits.  But it is more convenient to have this in a single
            # word, so some bit manipulations are necessary... - PH]
            # The bit pattern of the 32-bit word is:
            #   31....24 23....16 15.....8 7......0
            #   00000000 ffffffff DDDDDDDD ddFFFFFF
            #     0 = zero bits (not part of the file number?)
            #     f/F = low/high bits of file number
            #     d/D = low/high bits of directory number
            # The directory and file number are then converted into decimal
            # and separated by a '-' to give the file number used in the 20D
            ValueConv => '(($val&0xffc0)>>6)*10000+(($val>>16)&0xff)+(($val&0x3f)<<8)',
            ValueConvInv => q{
                my $d = int($val/10000);
                my $f = $val - $d * 10000;
                return (($d<<6) & 0xffc0) + (($f & 0xff)<<16) + (($f>>8) & 0x3f);
            },
            PrintConv => '$_=$val,s/(\d+)(\d{4})/$1-$2/,$_',
            PrintConvInv => '$val=~s/-//g;$val',
        },
        { #16
            Name => 'FileNumber',
            Condition => '$$self{Model} =~ /\b(30D|400D|REBEL XTi|Kiss Digital X|K236)\b/',
            Format => 'int32u',
            Notes => q{
                the location of the upper 4 bits of the directory number is a mystery for
                the EOS 30D, so the reported directory number will be incorrect for original
                images with a directory number of 164 or greater
            },
            # Thanks to Emil Sit for figuring this out:
            # [more insane bit maniplations like the 20D/350D above, but this time we
            # appear to have lost the upper 4 bits of the directory number (this was
            # verified through tests with directory numbers 100, 222, 801 and 999) - PH]
            # The bit pattern for the 30D is: (see 20D notes above for more information)
            #   31....24 23....16 15.....8 7......0
            #   00000000 ffff0000 ddddddFF FFFFFFFF
            # [NOTE: the 4 high order directory bits don't appear in this record, but
            # I have chosen to write them into bits 16-19 since these 4 zero bits look
            # very suspicious, and are a convenient place to store this information - PH]
            ValueConv  => q{
                my $d = ($val & 0xffc00) >> 10;
                # we know there are missing bits if directory number is < 100
                $d += 0x40 while $d < 100;  # (repair the damage as best we can)
                return $d*10000 + (($val&0x3ff)<<4) + (($val>>20)&0x0f);
            },
            ValueConvInv => q{
                my $d = int($val/10000);
                my $f = $val - $d * 10000;
                return ($d << 10) + (($f>>4)&0x3ff) + (($f&0x0f)<<20);
            },
            PrintConv => '$_=$val,s/(\d+)(\d{4})/$1-$2/,$_',
            PrintConvInv => '$val=~s/-//g;$val',
        },
        { #7 (1D, 1Ds)
            Name => 'ShutterCount',
            Condition => 'GetByteOrder() eq "MM"',
            Format => 'int32u',
        },
        { #7 (1DmkII, 1DSmkII, 1DSmkIIN)
            Name => 'ShutterCount',
            Condition => '$$self{Model} =~ /\b1Ds? Mark II\b/',
            Format => 'int32u',
            ValueConv => '($val>>16)|(($val&0xffff)<<16)',
            ValueConvInv => '($val>>16)|(($val&0xffff)<<16)',
        },
        # 5D gives a single byte value (unknown)
        # 40D stores all zeros
    ],
    3 => { #PH
        Name => 'BracketMode',
        PrintConv => {
            0 => 'Off',
            1 => 'AEB',
            2 => 'FEB',
            3 => 'ISO',
            4 => 'WB',
        },
    },
    4 => 'BracketValue', #PH
    5 => 'BracketShotNumber', #PH
    6 => { #PH
        Name => 'RawJpgQuality',
        RawConv => '$val<=0 ? undef : $val',
        PrintConv => \%canonQuality,
    },
    7 => { #PH
        Name => 'RawJpgSize',
        RawConv => '$val<0 ? undef : $val',
        PrintConv => \%canonImageSize,
    },
    8 => { #PH
        Name => 'LongExposureNoiseReduction2',
        Notes => q{
            for some modules this gives the long exposure noise reduction applied to the
            image, but for other models this just reflects the setting independent of
            whether or not it was applied
        },
        RawConv => '$val<0 ? undef : $val',
        PrintConv => {
            0 => 'Off',
            1 => 'On (1D)',
            3 => 'On',
            4 => 'Auto',
        },
    },
    9 => { #PH
        Name => 'WBBracketMode',
        PrintConv => {
            0 => 'Off',
            1 => 'On (shift AB)',
            2 => 'On (shift GM)',
        },
    },
    12 => 'WBBracketValueAB', #PH
    13 => 'WBBracketValueGM', #PH
    14 => { #PH
        Name => 'FilterEffect',
        RawConv => '$val==-1 ? undef : $val',
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
        },
    },
    15 => { #PH
        Name => 'ToningEffect',
        RawConv => '$val==-1 ? undef : $val',
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
        },
    },
    16 => { #PH
        %ciMacroMagnification,
        # MP-E 65mm on 5DmkII: 44=5x,52~=3.9x,56~=3.3x,62~=2.6x,75=1x
        # ME-E 65mm on 40D/450D: 72 for all samples (not valid)
        Condition => q{
            $$self{LensType} and $$self{LensType} == 124 and
            $$self{Model} !~ /\b(40D|450D|REBEL XSi|Kiss X2)\b/
        },
        Notes => q{
            currently decoded only for the MP-E 65mm f/2.8 1-5x Macro Photo, and not
            valid for all camera models
        },
    },
    # 17 - values: 0, 3, 4
    # 18 - same as LiveViewShooting for all my samples (5DmkII, 50D) - PH
    19 => { #PH
        # Note: this value is not displayed by Canon ImageBrowser for the following
        # models with the live view feature:  1DmkIII, 1DSmkIII, 40D, 450D, 1000D
        # (this tag could be valid only for some firmware versions:
        # http://www.breezesys.com/forum/showthread.php?p=16980)
        Name => 'LiveViewShooting',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    # 22 - values: 0, 1
    # 23 - values: 0, 21, 22
    25 => { #PH
        Name => 'FlashExposureLock',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
);

# Internal serial number information (MakerNotes tag 0x96) (ref PH)
%Image::ExifTool::Canon::SerialInfo = (
    %binaryDataAttrs,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    9 => {
        Name => 'InternalSerialNumber',
        Format => 'string',
    },
);

# Cropping information (MakerNotes tag 0x98) (ref PH)
%Image::ExifTool::Canon::CropInfo = (
    %binaryDataAttrs,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => 'CropLeftMargin',  # (NC, may be right)
    1 => 'CropRightMargin',
    2 => 'CropTopMargin',   # (NC, may be bottom)
    3 => 'CropBottomMargin',
);

# Aspect ratio information (MakerNotes tag 0x9a) (ref PH)
%Image::ExifTool::Canon::AspectInfo = (
    %binaryDataAttrs,
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'AspectRatio',
        PrintConv => {
            0 => '3:2',
            1 => '1:1',
            2 => '4:3',
            7 => '16:9',
            8 => '4:5',
        },
    },
    1 => 'CroppedImageWidth', # (could use a better name for these)
    2 => 'CroppedImageHeight',
);

# Color information (MakerNotes tag 0xa0)
%Image::ExifTool::Canon::Processing = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    1 => { #PH
        Name => 'ToneCurve',
        PrintConv => {
            0 => 'Standard',
            1 => 'Manual',
            2 => 'Custom',
        },
    },
    2 => { #12
        Name => 'Sharpness',
        Notes => 'all models except the 20D and 350D',
        Condition => '$$self{Model} !~ /\b(20D|350D|REBEL XT|Kiss Digital N)\b/',
        Priority => 0,  # (maybe not as reliable as other sharpness values)
    },
    3 => { #PH
        Name => 'SharpnessFrequency', # PatternSharpness?
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'n/a',
            1 => 'Lowest',
            2 => 'Low',
            3 => 'Standard',
            4 => 'High',
            5 => 'Highest',
        },
    },
    4 => 'SensorRedLevel', #PH
    5 => 'SensorBlueLevel', #PH
    6 => 'WhiteBalanceRed', #PH
    7 => 'WhiteBalanceBlue', #PH
    8 => { #PH
        Name => 'WhiteBalance',
        RawConv => '$val < 0 ? undef : $val',
        PrintConv => \%canonWhiteBalance,
        SeparateTable => 1,
    },
    9 => 'ColorTemperature', #6
    10 => { #12
        Name => 'PictureStyle',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    11 => { #PH
        Name => 'DigitalGain',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    12 => { #PH
        Name => 'WBShiftAB',
        Notes => 'positive is a shift toward amber',
    },
    13 => { #PH
        Name => 'WBShiftGM',
        Notes => 'positive is a shift toward green',
    },
);

# Color balance information (MakerNotes tag 0xa9) (ref PH)
%Image::ExifTool::Canon::ColorBalance = (
    %binaryDataAttrs,
    NOTES => 'These tags are used by the 10D and 300D.',
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    # red,green1,green2,blue (ref 2)
    0  => { Name => 'WB_RGGBLevelsAuto',       Format => 'int16s[4]' },
    4  => { Name => 'WB_RGGBLevelsDaylight',   Format => 'int16s[4]' },
    8  => { Name => 'WB_RGGBLevelsShade',      Format => 'int16s[4]' },
    12 => { Name => 'WB_RGGBLevelsCloudy',     Format => 'int16s[4]' },
    16 => { Name => 'WB_RGGBLevelsTungsten',   Format => 'int16s[4]' },
    20 => { Name => 'WB_RGGBLevelsFluorescent',Format => 'int16s[4]' },
    24 => { Name => 'WB_RGGBLevelsFlash',      Format => 'int16s[4]' },
    28 => { Name => 'WB_RGGBLevelsCustom',     Format => 'int16s[4]' },
    32 => { Name => 'WB_RGGBLevelsKelvin',     Format => 'int16s[4]' },
);

# Measured color levels (MakerNotes tag 0xaa) (ref 37)
%Image::ExifTool::Canon::MeasuredColor = (
    %binaryDataAttrs,
    FORMAT => 'int16u',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => {
        # this is basically the inverse of WB_RGGBLevelsMeasured (ref 37)
        Name => 'MeasuredRGGB',
        Format => 'int16u[4]',
    },
    # 5 - observed values: 0, 1 - PH
);

# Flags information (MakerNotes tag 0xb0) (ref PH)
%Image::ExifTool::Canon::Flags = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => 'ModifiedParamFlag',
);

# Modified information (MakerNotes tag 0xb1) (ref PH)
%Image::ExifTool::Canon::ModifiedInfo = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => {
        Name => 'ModifiedToneCurve',
        PrintConv => {
            0 => 'Standard',
            1 => 'Manual',
            2 => 'Custom',
        },
    },
    2 => {
        Name => 'ModifiedSharpness',
        Notes => '1D and 5D only',
        Condition => '$$self{Model} =~ /\b(1D|5D)/',
    },
    3 => {
        Name => 'ModifiedSharpnessFreq', # ModifiedPatternSharpness?
        PrintConv => {
            0 => 'n/a',
            1 => 'Lowest',
            2 => 'Low',
            3 => 'Standard',
            4 => 'High',
            5 => 'Highest',
        },
    },
    4 => 'ModifiedSensorRedLevel',
    5 => 'ModifiedSensorBlueLevel',
    6 => 'ModifiedWhiteBalanceRed',
    7 => 'ModifiedWhiteBalanceBlue',
    8 => {
        Name => 'ModifiedWhiteBalance',
        PrintConv => \%canonWhiteBalance,
        SeparateTable => 'WhiteBalance',
    },
    9 => 'ModifiedColorTemp',
    10 => {
        Name => 'ModifiedPictureStyle',
        PrintHex => 1,
        SeparateTable => 'PictureStyle',
        PrintConv => \%pictureStyles,
    },
    11 => {
        Name => 'ModifiedDigitalGain',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
);

# Preview image information (MakerNotes tag 0xb6)
# - The 300D writes a 1536x1024 preview image that is accessed
#   through this information - decoded by PH 12/14/03
%Image::ExifTool::Canon::PreviewImageInfo = (
    %binaryDataAttrs,
    FORMAT => 'int32u',
    FIRST_ENTRY => 1,
    IS_OFFSET => [ 5 ],   # tag 5 is 'IsOffset'
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
# the size of the preview block in 2-byte increments
#    0 => {
#        Name => 'PreviewImageInfoWords',
#    },
    1 => {
        Name => 'PreviewQuality',
        PrintConv => \%canonQuality,
    },
    2 => {
        Name => 'PreviewImageLength',
        OffsetPair => 5,   # point to associated offset
        DataTag => 'PreviewImage',
        Protected => 2,
    },
    3 => 'PreviewImageWidth',
    4 => 'PreviewImageHeight',
    5 => {
        Name => 'PreviewImageStart',
        Flags => 'IsOffset',
        OffsetPair => 2,  # associated byte count tagID
        DataTag => 'PreviewImage',
        Protected => 2,
    },
    # NOTE: The size of the PreviewImageInfo structure is incorrectly
    # written as 48 bytes (Count=12, Format=int32u), but only the first
    # 6 int32u values actually exist
);

# Sensor information (MakerNotes tag 0xe0) (ref 12)
%Image::ExifTool::Canon::SensorInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    # Note: Don't make these writable because it confuses Canon decoding software
    # if these are changed
    1 => 'SensorWidth',
    2 => 'SensorHeight',
    5 => 'SensorLeftBorder', #2
    6 => 'SensorTopBorder', #2
    7 => 'SensorRightBorder', #2
    8 => 'SensorBottomBorder', #2
    9 => { #22
        Name => 'BlackMaskLeftBorder',
        Notes => q{
            coordinates for the area to the left or right of the image used to calculate
            the average black level
        },
    },
    10 => 'BlackMaskTopBorder', #22
    11 => 'BlackMaskRightBorder', #22
    12 => 'BlackMaskBottomBorder', #22
);

# Color data (MakerNotes tag 0x4001, count=582) (ref 12)
%Image::ExifTool::Canon::ColorData1 = (
    %binaryDataAttrs,
    NOTES => 'These tags are used by the 20D and 350D.',
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    IS_SUBDIR => [ 0x4b ],
    # 0x00: size of record in bytes - PH
    # (dcraw 8.81 uses index 0x19 for WB)
    0x19 => { Name => 'WB_RGGBLevelsAsShot',      Format => 'int16s[4]' },
    0x1d => 'ColorTempAsShot',
    0x1e => { Name => 'WB_RGGBLevelsAuto',        Format => 'int16s[4]' },
    0x22 => 'ColorTempAuto',
    0x23 => { Name => 'WB_RGGBLevelsDaylight',    Format => 'int16s[4]' },
    0x27 => 'ColorTempDaylight',
    0x28 => { Name => 'WB_RGGBLevelsShade',       Format => 'int16s[4]' },
    0x2c => 'ColorTempShade',
    0x2d => { Name => 'WB_RGGBLevelsCloudy',      Format => 'int16s[4]' },
    0x31 => 'ColorTempCloudy',
    0x32 => { Name => 'WB_RGGBLevelsTungsten',    Format => 'int16s[4]' },
    0x36 => 'ColorTempTungsten',
    0x37 => { Name => 'WB_RGGBLevelsFluorescent', Format => 'int16s[4]' },
    0x3b => 'ColorTempFluorescent',
    0x3c => { Name => 'WB_RGGBLevelsFlash',       Format => 'int16s[4]' },
    0x40 => 'ColorTempFlash',
    0x41 => { Name => 'WB_RGGBLevelsCustom1',     Format => 'int16s[4]' },
    0x45 => 'ColorTempCustom1',
    0x46 => { Name => 'WB_RGGBLevelsCustom2',     Format => 'int16s[4]' },
    0x4a => 'ColorTempCustom2',
    0x4b => { #PH
        Name => 'ColorCalib',
        Format => 'undef[120]',
        Unknown => 1, # (all tags are unknown, so we can avoid processing entire directory)
        Notes => 'A, B, C, Temperature',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorCalib' }
    },
);

# Color data (MakerNotes tag 0x4001, count=653) (ref 12)
%Image::ExifTool::Canon::ColorData2 = (
    %binaryDataAttrs,
    NOTES => 'These tags are used by the 1DmkII and 1DSmkII.',
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    IS_SUBDIR => [ 0xa4 ],
    0x18 => { Name => 'WB_RGGBLevelsAuto',       Format => 'int16s[4]' },
    0x1c => 'ColorTempAuto',
    0x1d => { Name => 'WB_RGGBLevelsUnknown',    Format => 'int16s[4]', Unknown => 1 },
    0x21 => { Name => 'ColorTempUnknown', Unknown => 1 },
    # (dcraw 8.81 uses index 0x22 for WB)
    0x22 => { Name => 'WB_RGGBLevelsAsShot',     Format => 'int16s[4]' },
    0x26 => 'ColorTempAsShot',
    0x27 => { Name => 'WB_RGGBLevelsDaylight',   Format => 'int16s[4]' },
    0x2b => 'ColorTempDaylight',
    0x2c => { Name => 'WB_RGGBLevelsShade',      Format => 'int16s[4]' },
    0x30 => 'ColorTempShade',
    0x31 => { Name => 'WB_RGGBLevelsCloudy',     Format => 'int16s[4]' },
    0x35 => 'ColorTempCloudy',
    0x36 => { Name => 'WB_RGGBLevelsTungsten',   Format => 'int16s[4]' },
    0x3a => 'ColorTempTungsten',
    0x3b => { Name => 'WB_RGGBLevelsFluorescent',Format => 'int16s[4]' },
    0x3f => 'ColorTempFluorescent',
    0x40 => { Name => 'WB_RGGBLevelsKelvin',     Format => 'int16s[4]' },
    0x44 => 'ColorTempKelvin',
    0x45 => { Name => 'WB_RGGBLevelsFlash',      Format => 'int16s[4]' },
    0x49 => 'ColorTempFlash',
    0x4a => { Name => 'WB_RGGBLevelsUnknown2',   Format => 'int16s[4]', Unknown => 1 },
    0x4e => { Name => 'ColorTempUnknown2', Unknown => 1 },
    0x4f => { Name => 'WB_RGGBLevelsUnknown3',   Format => 'int16s[4]', Unknown => 1 },
    0x53 => { Name => 'ColorTempUnknown3', Unknown => 1 },
    0x54 => { Name => 'WB_RGGBLevelsUnknown4',   Format => 'int16s[4]', Unknown => 1 },
    0x58 => { Name => 'ColorTempUnknown4', Unknown => 1 },
    0x59 => { Name => 'WB_RGGBLevelsUnknown5',   Format => 'int16s[4]', Unknown => 1 },
    0x5d => { Name => 'ColorTempUnknown5', Unknown => 1 },
    0x5e => { Name => 'WB_RGGBLevelsUnknown6',   Format => 'int16s[4]', Unknown => 1 },
    0x62 => { Name => 'ColorTempUnknown6', Unknown => 1 },
    0x63 => { Name => 'WB_RGGBLevelsUnknown7',   Format => 'int16s[4]', Unknown => 1 },
    0x67 => { Name => 'ColorTempUnknown7', Unknown => 1 },
    0x68 => { Name => 'WB_RGGBLevelsUnknown8',   Format => 'int16s[4]', Unknown => 1 },
    0x6c => { Name => 'ColorTempUnknown8', Unknown => 1 },
    0x6d => { Name => 'WB_RGGBLevelsUnknown9',   Format => 'int16s[4]', Unknown => 1 },
    0x71 => { Name => 'ColorTempUnknown9', Unknown => 1 },
    0x72 => { Name => 'WB_RGGBLevelsUnknown10',  Format => 'int16s[4]', Unknown => 1 },
    0x76 => { Name => 'ColorTempUnknown10', Unknown => 1 },
    0x77 => { Name => 'WB_RGGBLevelsUnknown11',  Format => 'int16s[4]', Unknown => 1 },
    0x7b => { Name => 'ColorTempUnknown11', Unknown => 1 },
    0x7c => { Name => 'WB_RGGBLevelsUnknown12',  Format => 'int16s[4]', Unknown => 1 },
    0x80 => { Name => 'ColorTempUnknown12', Unknown => 1 },
    0x81 => { Name => 'WB_RGGBLevelsUnknown13',  Format => 'int16s[4]', Unknown => 1 },
    0x85 => { Name => 'ColorTempUnknown13', Unknown => 1 },
    0x86 => { Name => 'WB_RGGBLevelsUnknown14',  Format => 'int16s[4]', Unknown => 1 },
    0x8a => { Name => 'ColorTempUnknown14', Unknown => 1 },
    0x8b => { Name => 'WB_RGGBLevelsUnknown15',  Format => 'int16s[4]', Unknown => 1 },
    0x8f => { Name => 'ColorTempUnknown15', Unknown => 1 },
    0x90 => { Name => 'WB_RGGBLevelsPC1',        Format => 'int16s[4]' },
    0x94 => 'ColorTempPC1',
    0x95 => { Name => 'WB_RGGBLevelsPC2',        Format => 'int16s[4]' },
    0x99 => 'ColorTempPC2',
    0x9a => { Name => 'WB_RGGBLevelsPC3',        Format => 'int16s[4]' },
    0x9e => 'ColorTempPC3',
    0x9f => { Name => 'WB_RGGBLevelsUnknown16',  Format => 'int16s[4]', Unknown => 1 },
    0xa3 => { Name => 'ColorTempUnknown16', Unknown => 1 },
    0xa4 => { #PH
        Name => 'ColorCalib',
        Format => 'undef[120]',
        Unknown => 1,
        Notes => 'A, B, C, Temperature',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorCalib' }
    },
    0x26a => { #PH
        Name => 'RawMeasuredRGGB',
        Format => 'int32u[4]',
        Notes => 'raw MeasuredRGGB values, before normalization',
        # swap words because the word ordering is big-endian, opposite to the byte ordering
        ValueConv => \&SwapWords,
        ValueConvInv => \&SwapWords,
    },
);

# Color data (MakerNotes tag 0x4001, count=796) (ref 12)
%Image::ExifTool::Canon::ColorData3 = (
    %binaryDataAttrs,
    NOTES => 'These tags are used by the 1DmkIIN, 5D, 30D and 400D.',
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    IS_SUBDIR => [ 0x85 ],
    0x00 => { #PH
        Name => 'ColorDataVersion',
        PrintConv => {
            1 => '1 (1DmkIIN/5D/30D/400D)',
        },
    },
    # 0x01-0x3e: RGGB coefficients, apparently specific to the
    # individual camera and possibly used for color calibration (ref 37)
    # (dcraw 8.81 uses index 0x3f for WB)
    0x3f => { Name => 'WB_RGGBLevelsAsShot',      Format => 'int16s[4]' },
    0x43 => 'ColorTempAsShot',
    0x44 => { Name => 'WB_RGGBLevelsAuto',        Format => 'int16s[4]' },
    0x48 => 'ColorTempAuto',
    # not sure exactly what 'Measured' values mean...
    0x49 => { Name => 'WB_RGGBLevelsMeasured',    Format => 'int16s[4]' },
    0x4d => 'ColorTempMeasured',
    0x4e => { Name => 'WB_RGGBLevelsDaylight',    Format => 'int16s[4]' },
    0x52 => 'ColorTempDaylight',
    0x53 => { Name => 'WB_RGGBLevelsShade',       Format => 'int16s[4]' },
    0x57 => 'ColorTempShade',
    0x58 => { Name => 'WB_RGGBLevelsCloudy',      Format => 'int16s[4]' },
    0x5c => 'ColorTempCloudy',
    0x5d => { Name => 'WB_RGGBLevelsTungsten',    Format => 'int16s[4]' },
    0x61 => 'ColorTempTungsten',
    0x62 => { Name => 'WB_RGGBLevelsFluorescent', Format => 'int16s[4]' },
    0x66 => 'ColorTempFluorescent',
    0x67 => { Name => 'WB_RGGBLevelsKelvin',      Format => 'int16s[4]' },
    0x6b => 'ColorTempKelvin',
    0x6c => { Name => 'WB_RGGBLevelsFlash',       Format => 'int16s[4]' },
    0x70 => 'ColorTempFlash',
    0x71 => { Name => 'WB_RGGBLevelsPC1',         Format => 'int16s[4]' },
    0x75 => 'ColorTempPC1',
    0x76 => { Name => 'WB_RGGBLevelsPC2',         Format => 'int16s[4]' },
    0x7a => 'ColorTempPC2',
    0x7b => { Name => 'WB_RGGBLevelsPC3',         Format => 'int16s[4]' },
    0x7f => 'ColorTempPC3',
    0x80 => { Name => 'WB_RGGBLevelsCustom',      Format => 'int16s[4]' },
    0x84 => 'ColorTempCustom',
    0x85 => { #37
        Name => 'ColorCalib',
        Format => 'undef[120]',
        Unknown => 1,
        Notes => 'B, C, A, Temperature',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorCalib' }
    },
    # 0xc5-0xc7: looks like black levels (ref 37)
    # 0xc8-0x1c7: some sort of color table (ref 37)
    0x248 => { #37
        Name => 'FlashOutput',
        ValueConv => '$val >= 255 ? 255 : exp(($val-200)/16*log(2))',
        ValueConvInv => '$val == 255 ? 255 : 200 + log($val)*16/log(2)',
        PrintConv => '$val == 255 ? "Strobe or Misfire" : sprintf("%.0f%%", $val * 100)',
        PrintConvInv => '$val =~ /^(\d(\.?\d*))/ ? $1 / 100 : 255',
    },
    0x249 => { #37
        Name => 'FlashBatteryLevel',
        # calibration points for external flash: 144=3.76V (almost empty), 192=5.24V (full)
        # - have seen a value of 201 with internal flash
        PrintConv => '$val ? sprintf("%.2fV", $val * 5 / 186) : "n/a"',
        PrintConvInv => '$val=~/^(\d+\.\d+)\s*V?$/i ? int($val*186/5+0.5) : 0',
    },
    0x24a => { #37
        Name => 'ColorTempFlashData',
        # 0 for no external flash, 35980 for 'Strobe or Misfire'
        # (lower than ColorTempFlash by up to 200 degrees)
        RawConv => '($val < 2000 or $val > 12000) ? undef : $val',
    },
    # 0x24b: inverse relationship with flash power (ref 37)
    # 0x286: has value 256 for correct exposure, less for under exposure (seen 96 minimum) (ref 37)
    0x287 => { #37
        Name => 'MeasuredRGGBData',
        Format => 'int32u[4]',
        Notes => 'MeasuredRGGB may be derived from these data values',
        # swap words because the word ordering is big-endian, opposite to the byte ordering
        ValueConv => \&SwapWords,
        ValueConvInv => \&SwapWords,
    },
    # 0x297: ranges from -10 to 30, higher for high ISO (ref 37)
);

# Color data (MakerNotes tag 0x4001, count=674|692|702|1227|1250|1251|1337|1338|1346) (ref PH)
%Image::ExifTool::Canon::ColorData4 = (
    %binaryDataAttrs,
    NOTES => q{
        These tags are used by the 1DmkIII, 1DSmkIII, 1DmkIV, 5DmkII, 7D, 40D, 50D,
        450D, 500D, 550D, 1000D and 1100D.
    },
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    IS_SUBDIR => [ 0x3f, 0xa8 ],
    0x00 => {
        Name => 'ColorDataVersion',
        PrintConv => {
            2 => '2 (1DmkIII)',
            3 => '3 (40D)',
            4 => '4 (1DSmkIII)',
            5 => '5 (450D/1000D)',
            6 => '6 (50D/5DmkII)',
            7 => '7 (500D/550D/7D/1DmkIV)',
            9 => '9 (1100D)',
        },
    },
    # 0x01-0x18: unknown RGGB coefficients (int16s[4]) (50D)
    # (dcraw 8.81 uses index 0x3f for WB)
    0x3f => {
        Name => 'ColorCoefs',
        Format => 'undef[210]', # ColorTempUnknown11 is last entry
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorCoefs' }
    },
    0xa8 => {
        Name => 'ColorCalib',
        Format => 'undef[120]',
        Unknown => 1,
        Notes => 'B, C, A, Temperature',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorCalib' }
    },
    0x280 => { #PH
        Name => 'RawMeasuredRGGB',
        Format => 'int32u[4]',
        Notes => 'raw MeasuredRGGB values, before normalization',
        # swap words because the word ordering is big-endian, opposite to the byte ordering
        ValueConv => \&SwapWords,
        ValueConvInv => \&SwapWords,
    },
);

# color coefficients (ref PH)
%Image::ExifTool::Canon::ColorCoefs = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x00 => { Name => 'WB_RGGBLevelsAsShot',      Format => 'int16s[4]' },
    0x04 => 'ColorTempAsShot',
    0x05 => { Name => 'WB_RGGBLevelsAuto',        Format => 'int16s[4]' },
    0x09 => 'ColorTempAuto',
    0x0a => { Name => 'WB_RGGBLevelsMeasured',    Format => 'int16s[4]' },
    0x0e => 'ColorTempMeasured',
    # the following Unknown values are set for the 50D and 5DmkII, and the
    # SRAW images of the 40D, and affect thumbnail display for the 50D/5DmkII
    # and conversion for all modes of the 40D
    0x0f => { Name => 'WB_RGGBLevelsUnknown',     Format => 'int16s[4]', Unknown => 1 },
    0x13 => { Name => 'ColorTempUnknown', Unknown => 1 },
    0x14 => { Name => 'WB_RGGBLevelsDaylight',    Format => 'int16s[4]' },
    0x18 => 'ColorTempDaylight',
    0x19 => { Name => 'WB_RGGBLevelsShade',       Format => 'int16s[4]' },
    0x1d => 'ColorTempShade',
    0x1e => { Name => 'WB_RGGBLevelsCloudy',      Format => 'int16s[4]' },
    0x22 => 'ColorTempCloudy',
    0x23 => { Name => 'WB_RGGBLevelsTungsten',    Format => 'int16s[4]' },
    0x27 => 'ColorTempTungsten',
    0x28 => { Name => 'WB_RGGBLevelsFluorescent',Format => 'int16s[4]' },
    0x2c => 'ColorTempFluorescent',
    # (changing the Kelvin values has no effect on image in DPP... why not?)
    0x2d => { Name => 'WB_RGGBLevelsKelvin',     Format => 'int16s[4]' },
    0x31 => 'ColorTempKelvin',
    0x32 => { Name => 'WB_RGGBLevelsFlash',      Format => 'int16s[4]' },
    0x36 => 'ColorTempFlash',
    0x37 => { Name => 'WB_RGGBLevelsUnknown2',   Format => 'int16s[4]', Unknown => 1 },
    0x3b => { Name => 'ColorTempUnknown2', Unknown => 1 },
    0x3c => { Name => 'WB_RGGBLevelsUnknown3',   Format => 'int16s[4]', Unknown => 1 },
    0x40 => { Name => 'ColorTempUnknown3', Unknown => 1 },
    0x41 => { Name => 'WB_RGGBLevelsUnknown4',   Format => 'int16s[4]', Unknown => 1 },
    0x45 => { Name => 'ColorTempUnknown4', Unknown => 1 },
    0x46 => { Name => 'WB_RGGBLevelsUnknown5',   Format => 'int16s[4]', Unknown => 1 },
    0x4a => { Name => 'ColorTempUnknown5', Unknown => 1 },
    0x4b => { Name => 'WB_RGGBLevelsUnknown6',   Format => 'int16s[4]', Unknown => 1 },
    0x4f => { Name => 'ColorTempUnknown6', Unknown => 1 },
    0x50 => { Name => 'WB_RGGBLevelsUnknown7',   Format => 'int16s[4]', Unknown => 1 },
    0x54 => { Name => 'ColorTempUnknown7', Unknown => 1 },
    0x55 => { Name => 'WB_RGGBLevelsUnknown8',   Format => 'int16s[4]', Unknown => 1 },
    0x59 => { Name => 'ColorTempUnknown8', Unknown => 1 },
    0x5a => { Name => 'WB_RGGBLevelsUnknown9',   Format => 'int16s[4]', Unknown => 1 },
    0x5e => { Name => 'ColorTempUnknown9', Unknown => 1 },
    0x5f => { Name => 'WB_RGGBLevelsUnknown10',  Format => 'int16s[4]', Unknown => 1 },
    0x63 => { Name => 'ColorTempUnknown10', Unknown => 1 },
    0x64 => { Name => 'WB_RGGBLevelsUnknown11',  Format => 'int16s[4]', Unknown => 1 },
    0x68 => { Name => 'ColorTempUnknown11', Unknown => 1 },
    0x69 => { Name => 'WB_RGGBLevelsUnknown12',  Format => 'int16s[4]', Unknown => 1 },
    0x6d => { Name => 'ColorTempUnknown12', Unknown => 1 },
    0x6e => { Name => 'WB_RGGBLevelsUnknown13',  Format => 'int16s[4]', Unknown => 1 },
    0x72 => { Name => 'ColorTempUnknown13', Unknown => 1 },
);

# color calibration (ref 37)
%Image::ExifTool::Canon::ColorCalib = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    # these coefficients are in a different order compared to older
    # models (A,B,C in ColorData1/2 vs. C,A,B in ColorData3/4) - PH
    # Coefficient A most closely matches the blue curvature, and
    # coefficient B most closely matches the red curvature, but the match
    # is not perfect, and I don't know what coefficient C is for (certainly
    # not a green coefficient) - PH
    NOTES => q{
        Camera color calibration data.  For the 20D, 350D, 1DmkII and 1DSmkII the
        order of the cooefficients is A, B, C, Temperature, but for newer models it
        is B, C, A, Temperature.  These tags are extracted only when the Unknown
        option is used.
    },
    0x00 => { Name => 'CameraColorCalibration01', %cameraColorCalibration },
    0x04 => { Name => 'CameraColorCalibration02', %cameraColorCalibration },
    0x08 => { Name => 'CameraColorCalibration03', %cameraColorCalibration },
    0x0c => { Name => 'CameraColorCalibration04', %cameraColorCalibration },
    0x10 => { Name => 'CameraColorCalibration05', %cameraColorCalibration },
    0x14 => { Name => 'CameraColorCalibration06', %cameraColorCalibration },
    0x18 => { Name => 'CameraColorCalibration07', %cameraColorCalibration },
    0x1c => { Name => 'CameraColorCalibration08', %cameraColorCalibration },
    0x20 => { Name => 'CameraColorCalibration09', %cameraColorCalibration },
    0x24 => { Name => 'CameraColorCalibration10', %cameraColorCalibration },
    0x28 => { Name => 'CameraColorCalibration11', %cameraColorCalibration },
    0x2c => { Name => 'CameraColorCalibration12', %cameraColorCalibration },
    0x30 => { Name => 'CameraColorCalibration13', %cameraColorCalibration },
    0x34 => { Name => 'CameraColorCalibration14', %cameraColorCalibration },
    0x38 => { Name => 'CameraColorCalibration15', %cameraColorCalibration },
);

# Color data (MakerNotes tag 0x4001, count=5120) (ref PH)
%Image::ExifTool::Canon::ColorData5 = (
    %binaryDataAttrs,
    NOTES => 'These tags are used by the PowerShot G10.',
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    IS_SUBDIR => [ 0x47 ],
    # 0x00 - oddly, this isn't ColorDataVersion (probably should have been version 8)
    0x47 => {
        Name => 'ColorCoefs',
        Format => 'undef[230]', # ColorTempUnknown13 is last entry
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorCoefs' }
    },
    0xba => { Name => 'CameraColorCalibration01', %cameraColorCalibration2,
              Notes => 'B, C, A, D, Temperature' },
    0xbf => { Name => 'CameraColorCalibration02', %cameraColorCalibration2 },
    0xc4 => { Name => 'CameraColorCalibration03', %cameraColorCalibration2 },
    0xc9 => { Name => 'CameraColorCalibration04', %cameraColorCalibration2 },
    0xce => { Name => 'CameraColorCalibration05', %cameraColorCalibration2 },
    0xd3 => { Name => 'CameraColorCalibration06', %cameraColorCalibration2 },
    0xd8 => { Name => 'CameraColorCalibration07', %cameraColorCalibration2 },
    0xdd => { Name => 'CameraColorCalibration08', %cameraColorCalibration2 },
    0xe2 => { Name => 'CameraColorCalibration09', %cameraColorCalibration2 },
    0xe7 => { Name => 'CameraColorCalibration10', %cameraColorCalibration2 },
    0xec => { Name => 'CameraColorCalibration11', %cameraColorCalibration2 },
    0xf1 => { Name => 'CameraColorCalibration12', %cameraColorCalibration2 },
    0xf6 => { Name => 'CameraColorCalibration13', %cameraColorCalibration2 },
    0xfb => { Name => 'CameraColorCalibration14', %cameraColorCalibration2 },
    0x100=> { Name => 'CameraColorCalibration15', %cameraColorCalibration2 },
);

# Color data (MakerNotes tag 0x4001, count=1273) (ref PH)
%Image::ExifTool::Canon::ColorData6 = (
    %binaryDataAttrs,
    NOTES => 'These tags are used by the EOS 600D.',
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    IS_SUBDIR => [ 0xbc ],
    0x00 => {
        Name => 'ColorDataVersion',
        PrintConv => {
            10 => '10 (600D)',
        },
    },
    0x3f => { Name => 'WB_RGGBLevelsAsShot',     Format => 'int16s[4]' },
    0x43 => 'ColorTempAsShot',
    0x44 => { Name => 'WB_RGGBLevelsAuto',       Format => 'int16s[4]' },
    0x48 => 'ColorTempAuto',
    0x49 => { Name => 'WB_RGGBLevelsMeasured',   Format => 'int16s[4]' },
    0x4d => 'ColorTempMeasured',
    0x4e => { Name => 'WB_RGGBLevelsUnknown',    Format => 'int16s[4]', Unknown => 1 },
    0x52 => { Name => 'ColorTempUnknown', Unknown => 1 },
    0x53 => { Name => 'WB_RGGBLevelsUnknown2',   Format => 'int16s[4]', Unknown => 1 },
    0x57 => { Name => 'ColorTempUnknown2', Unknown => 1 },
    0x58 => { Name => 'WB_RGGBLevelsUnknown3',   Format => 'int16s[4]', Unknown => 1 },
    0x5c => { Name => 'ColorTempUnknown3', Unknown => 1 },
    0x5d => { Name => 'WB_RGGBLevelsUnknown4',   Format => 'int16s[4]', Unknown => 1 },
    0x61 => { Name => 'ColorTempUnknown4', Unknown => 1 },
    0x62 => { Name => 'WB_RGGBLevelsUnknown5',   Format => 'int16s[4]', Unknown => 1 },
    0x66 => { Name => 'ColorTempUnknown5', Unknown => 1 },
    0x67 => { Name => 'WB_RGGBLevelsDaylight',   Format => 'int16s[4]' },
    0x6b => 'ColorTempDaylight',
    0x6c => { Name => 'WB_RGGBLevelsShade',      Format => 'int16s[4]' },
    0x70 => 'ColorTempShade',
    0x71 => { Name => 'WB_RGGBLevelsCloudy',     Format => 'int16s[4]' },
    0x75 => 'ColorTempCloudy',
    0x76 => { Name => 'WB_RGGBLevelsTungsten',   Format => 'int16s[4]' },
    0x7a => 'ColorTempTungsten',
    0x7b => { Name => 'WB_RGGBLevelsFluorescent',Format => 'int16s[4]' },
    0x7f => 'ColorTempFluorescent',
    0x80 => { Name => 'WB_RGGBLevelsKelvin',     Format => 'int16s[4]' },
    0x84 => 'ColorTempKelvin',
    0x85 => { Name => 'WB_RGGBLevelsFlash',      Format => 'int16s[4]' },
    0x89 => 'ColorTempFlash',
    0x8a => { Name => 'WB_RGGBLevelsUnknown6',   Format => 'int16s[4]', Unknown => 1 },
    0x8e => { Name => 'ColorTempUnknown6', Unknown => 1 },
    0x8f => { Name => 'WB_RGGBLevelsUnknown7',   Format => 'int16s[4]', Unknown => 1 },
    0x93 => { Name => 'ColorTempUnknown7', Unknown => 1 },
    0x94 => { Name => 'WB_RGGBLevelsUnknown8',   Format => 'int16s[4]', Unknown => 1 },
    0x98 => { Name => 'ColorTempUnknown8', Unknown => 1 },
    0x99 => { Name => 'WB_RGGBLevelsUnknown9',   Format => 'int16s[4]', Unknown => 1 },
    0x9d => { Name => 'ColorTempUnknown9', Unknown => 1 },
    0x9e => { Name => 'WB_RGGBLevelsUnknown10',  Format => 'int16s[4]', Unknown => 1 },
    0xa2 => { Name => 'ColorTempUnknown10', Unknown => 1 },
    0xa3 => { Name => 'WB_RGGBLevelsUnknown11',  Format => 'int16s[4]', Unknown => 1 },
    0xa7 => { Name => 'ColorTempUnknown11', Unknown => 1 },
    0xa8 => { Name => 'WB_RGGBLevelsUnknown12',  Format => 'int16s[4]', Unknown => 1 },
    0xac => { Name => 'ColorTempUnknown12', Unknown => 1 },
    0xad => { Name => 'WB_RGGBLevelsUnknown13',  Format => 'int16s[4]', Unknown => 1 },
    0xb1 => { Name => 'ColorTempUnknown13', Unknown => 1 },
    0xb2 => { Name => 'WB_RGGBLevelsUnknown14',  Format => 'int16s[4]', Unknown => 1 },
    0xb6 => { Name => 'ColorTempUnknown14', Unknown => 1 },
    0xb7 => { Name => 'WB_RGGBLevelsUnknown15',  Format => 'int16s[4]', Unknown => 1 },
    0xbb => { Name => 'ColorTempUnknown15', Unknown => 1 },
    0xbc => {
        Name => 'ColorCalib',
        Format => 'undef[120]',
        Unknown => 1,
        Notes => 'B, C, A, Temperature',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorCalib' }
    },
    0x194 => { #PH
        Name => 'RawMeasuredRGGB',
        Format => 'int32u[4]',
        Notes => 'raw MeasuredRGGB values, before normalization',
        # swap words because the word ordering is big-endian, opposite to the byte ordering
        ValueConv => \&SwapWords,
        ValueConvInv => \&SwapWords,
    },
);

# Unknown color data (MakerNotes tag 0x4001)
%Image::ExifTool::Canon::ColorDataUnknown = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
);

# Color information (MakerNotes tag 0x4003) (ref PH)
%Image::ExifTool::Canon::ColorInfo = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => {
        Condition => '$$self{Model} =~ /EOS-1D/',
        Name => 'Saturation',
        %Image::ExifTool::Exif::printParameter,
    },
    2 => {
        Name => 'ColorTone',
        %Image::ExifTool::Exif::printParameter,
    },
    3 => {
        Name => 'ColorSpace',
        RawConv => '$val ? $val : undef', # ignore tag if zero
        PrintConv => {
            1 => 'sRGB',
            2 => 'Adobe RGB',
        },
    },
);

# AF micro-adjustment information (MakerNotes tag 0x4013) (ref PH)
%Image::ExifTool::Canon::AFMicroAdj = (
    %binaryDataAttrs,
    FORMAT => 'int32s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => {
        Name => 'AFMicroAdjActive',
        PrintConv => {
            0 => 'No',
            1 => 'Yes',
        },
    },
    2 => {
        Name => 'AFMicroAdjValue',
        Format => 'rational64s',
    },
);

# Vignetting correction information (MakerNotes tag 0x4015)
%Image::ExifTool::Canon::VignettingCorr = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        This information is found in images from the 1DmkIV, 5DmkII, 7D, 50D, 500D
        and 550D.
    },
    # 0 => 'PeripheralLightingVersion', value = 0x1000
    2 => {
        Name => 'PeripheralLighting',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    6 => 'PeripheralLightingValue',
    # 10 - flags?
    11 => {
        Name => 'OriginalImageWidth',
        Notes => 'full size of original image before being rotated or scaled in camera',
    },
    12 => 'OriginalImageHeight',
);

# More Vignetting correction information (MakerNotes tag 0x4016)
%Image::ExifTool::Canon::VignettingCorr2 = (
    %binaryDataAttrs,
    FORMAT => 'int32s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    5 => {
        Name => 'PeripheralLightingSetting',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
);

# Auto Lighting Optimizater information (MakerNotes tag 0x4018) (ref PH)
%Image::ExifTool::Canon::LightingOpt = (
    %binaryDataAttrs,
    FORMAT => 'int32s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'This information is new in images from the EOS 7D.',
    2 => {
        Name => 'AutoLightingOptimizer',
        PrintConv => {
            0 => 'Standard',
            1 => 'Low',
            2 => 'Strong',
            3 => 'Off',
        },
    },
);

# Lens information (MakerNotes tag 0x4019) (ref 20)
%Image::ExifTool::Canon::LensInfo = (
    %binaryDataAttrs,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => { # this doesn't seem to be valid for some models (ie. 550D, 7D?, 1DmkIV?)
        Name => 'LensSerialNumber',
        Notes => q{
            apparently this is an internal serial number because it doesn't correspond
            to the one printed on the lens
        },
        Condition => '$$valPt !~ /^\0\0\0\0/', # (rules out 550D and older lenses)
        Format => 'undef[5]',
        ValueConv => 'unpack("H*", $val)',
        ValueConvInv => 'pack("H*", $val)',
    },
);

# Subject mode ambience information (MakerNotes tag 0x4020) (ref PH)
%Image::ExifTool::Canon::Ambience = (
    %binaryDataAttrs,
    FORMAT => 'int32s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => {
        Name => 'AmbienceSelection',
        PrintConv => {
            0 => 'Standard',
            1 => 'Vivid',
            2 => 'Warm',
            3 => 'Soft',
            4 => 'Cool',
            5 => 'Intense',
            6 => 'Brighter',
            7 => 'Darker',
            8 => 'Monochrome',
        },
    },
);

# Creative filter information (MakerNotes tag 0x4024) (ref PH)
%Image::ExifTool::Canon::FilterInfo = (
    PROCESS_PROC => \&ProcessFilters,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Information about creative filter settings.',
    0x101 => {
        Name => 'GrainyBWFilter',
        Description => 'Grainy B/W Filter',
        PrintConv => '$val == -1 ? "Off" : "On ($val)"',
        PrintConvInv => '$val =~ /([-+]?\d+)/ ? $1 : -1',
    },
    0x201 => {
        Name => 'SoftFocusFilter',
        PrintConv => '$val == -1 ? "Off" : "On ($val)"',
        PrintConvInv => '$val =~ /([-+]?\d+)/ ? $1 : -1',
    },
    0x301 => {
        Name => 'ToyCameraFilter',
        PrintConv => '$val == -1 ? "Off" : "On ($val)"',
        PrintConvInv => '$val =~ /([-+]?\d+)/ ? $1 : -1',
    },
    0x401 => {
        Name => 'MiniatureFilter',
        PrintConv => '$val == -1 ? "Off" : "On ($val)"',
        PrintConvInv => '$val =~ /([-+]?\d+)/ ? $1 : -1',
    },
    0x0402 => {
        Name => 'MiniatureFilterOrientation',
        PrintConv => {
            0 => 'Horizontal',
            1 => 'Vertical',
        },
    },
    0x403=> 'MiniatureFilterPosition',
    # 0x404 - value: 0, 345, 518, ... (miniature filter width maybe?)
);

# Canon CNTH atoms (ref PH)
%Image::ExifTool::Canon::CNTH = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'Canon', 2 => 'Video' },
    NOTES => q{
        Canon-specific QuickTime tags found in the CNTH atom of MOV videos from some
        cameras such as the PowerShot S95.
    },
    CNDA => {
        Name => 'ThumbnailImage',
        Format => 'undef',
        Notes => 'the full THM image, embedded metadata is extracted as the first sub-document',
        RawConv => q{
            $$self{DOC_NUM} = ++$$self{DOC_COUNT};
            $self->ExtractInfo(\$val, { ReEntry => 1 });
            $$self{DOC_NUM} = 0;
            return \$val;
        },
    },
);

# Canon composite tags
%Image::ExifTool::Canon::Composite = (
    GROUPS => { 2 => 'Camera' },
    DriveMode => {
        Require => {
            0 => 'ContinuousDrive',
            1 => 'SelfTimer',
        },
        ValueConv => '$val[0] ? 0 : ($val[1] ? 1 : 2)',
        PrintConv => {
            0 => 'Continuous Shooting',
            1 => 'Self-timer Operation',
            2 => 'Single-frame Shooting',
        },
    },
    Lens => {
        Require => {
            0 => 'ShortFocal',
            1 => 'LongFocal',
        },
        ValueConv => '$val[0]',
        PrintConv => 'Image::ExifTool::Canon::PrintFocalRange(@val)',
    },
    Lens35efl => {
        Description => 'Lens',
        Require => {
            0 => 'ShortFocal',
            1 => 'LongFocal',
            3 => 'Lens',
        },
        Desire => {
            2 => 'ScaleFactor35efl',
        },
        ValueConv => '$val[3] * ($val[2] ? $val[2] : 1)',
        PrintConv => '$prt[3] . ($val[2] ? sprintf(" (35 mm equivalent: %s)",Image::ExifTool::Canon::PrintFocalRange(@val)) : "")',
    },
    ShootingMode => {
        Require => {
            0 => 'CanonExposureMode',
            1 => 'EasyMode',
        },
        Desire => {
            2 => 'BulbDuration',
        },
        # most Canon models set CanonExposureMode to Manual (4) for Bulb shots,
        # but the 1DmkIII uses a value of 7 for Bulb, so use this for other
        # models too (Note that Canon DPP reports "Manual Exposure" here)
        ValueConv => '$val[0] ? (($val[0] eq "4" and $val[2]) ? 7 : $val[0]) : $val[1] + 10',
        PrintConv => '$val eq "7" ? "Bulb" : ($val[0] ? $prt[0] : $prt[1])',
    },
    FlashType => {
        Notes => q{
            may report "Built-in Flash" for some Canon cameras with external flash in
            manual mode
        },
        Require => {
            0 => 'FlashBits',
        },
        RawConv => '$val[0] ? $val : undef',
        ValueConv => '$val[0]&(1<<14)? 1 : 0',
        PrintConv => {
            0 => 'Built-In Flash',
            1 => 'External',
        },
    },
    RedEyeReduction => {
        Require => {
            0 => 'CanonFlashMode',
            1 => 'FlashBits',
        },
        RawConv => '$val[1] ? $val : undef',
        ValueConv => '($val[0]==3 or $val[0]==4 or $val[0]==6) ? 1 : 0',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    # same as FlashExposureComp, but undefined if no flash
    ConditionalFEC => {
        Description => 'Flash Exposure Compensation',
        Require => {
            0 => 'FlashExposureComp',
            1 => 'FlashBits',
        },
        RawConv => '$val[1] ? $val : undef',
        ValueConv => '$val[0]',
        PrintConv => '$prt[0]',
    },
    # hack to assume 1st curtain unless we see otherwise
    ShutterCurtainHack => {
        Description => 'Shutter Curtain Sync',
        Desire => {
            0 => 'ShutterCurtainSync',
        },
        Require => {
            1 => 'FlashBits',
        },
        RawConv => '$val[1] ? $val : undef',
        ValueConv => 'defined($val[0]) ? $val[0] : 0',
        PrintConv => {
            0 => '1st-curtain sync',
            1 => '2nd-curtain sync',
        },
    },
    WB_RGGBLevels => {
        Require => {
            0 => 'Canon:WhiteBalance',
        },
        Desire => {
            1 => 'WB_RGGBLevelsAsShot',
            # indices of the following entries correspond to Canon:WhiteBalance + 2
            2 => 'WB_RGGBLevelsAuto',
            3 => 'WB_RGGBLevelsDaylight',
            4 => 'WB_RGGBLevelsCloudy',
            5 => 'WB_RGGBLevelsTungsten',
            6 => 'WB_RGGBLevelsFluorescent',
            7 => 'WB_RGGBLevelsFlash',
            8 => 'WB_RGGBLevelsCustom',
           10 => 'WB_RGGBLevelsShade',
           11 => 'WB_RGGBLevelsKelvin',
        },
        ValueConv => '$val[1] ? $val[1] : $val[($val[0] || 0) + 2]',
    },
    ISO => {
        Priority => 0,  # let EXIF:ISO take priority
        Desire => {
            0 => 'Canon:CameraISO',
            1 => 'Canon:BaseISO',
            2 => 'Canon:AutoISO',
        },
        Notes => 'use CameraISO if numerical, otherwise calculate as BaseISO * AutoISO / 100',
        ValueConv => q{
            return $val[0] if $val[0] and $val[0] =~ /^\d+$/;
            return undef unless $val[1] and $val[2];
            return $val[1] * $val[2] / 100;
        },
        PrintConv => 'sprintf("%.0f",$val)',
    },
    DigitalZoom => {
        Require => {
            0 => 'Canon:ZoomSourceWidth',
            1 => 'Canon:ZoomTargetWidth',
            2 => 'Canon:DigitalZoom',
        },
        RawConv => q{
            ToFloat(@val);
            return undef unless $val[2] and $val[2] == 3 and $val[0] and $val[1];
            return $val[1] / $val[0];
        },
        PrintConv => 'sprintf("%.2fx",$val)',
    },
    OriginalDecisionData => {
        Flags => ['Writable','Protected'],
        WriteGroup => 'MakerNotes',
        Require => 'OriginalDecisionDataOffset',
        RawConv => 'Image::ExifTool::Canon::ReadODD($self,$val[0])',
    },
    FileNumber => {
        Groups => { 2 => 'Image' },
        Writable => 1,
        WriteCheck => '$val=~/\d+-\d+/ ? undef : "Invalid format"',
        DelCheck => '"Can\'t delete"',
        Require => {
            0 => 'DirectoryIndex',
            1 => 'FileIndex',
        },
        WriteAlso => {
            DirectoryIndex => '$val=~/(\d+)-(\d+)/; $1',
            FileIndex => '$val=~/(\d+)-(\d+)/; $2',
        },
        ValueConv => 'sprintf("%.3d-%.4d",@val)',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::Canon');

#------------------------------------------------------------------------------
# Return lens name with teleconverter if applicable
# Inputs: 0) lens name string, 1) short focal length
# Returns: lens string with tc if appropriate
sub LensWithTC($$)
{
    my ($lens, $shortFocal) = @_;

    # add teleconverter multiplication factor if applicable
    # (and if the LensType doesn't already include one)
    if (not $lens =~ /x$/ and $lens =~ /(\d+)/) {
        my $sf = $1;    # short focal length
        my $tc;
        foreach $tc (1, 1.4, 2, 2.8) {
            next if abs($shortFocal - $sf * $tc) > 0.9;
            $lens .= " + ${tc}x" if $tc > 1;
            last;
        }
    }
    return $lens;
}

#------------------------------------------------------------------------------
# Attempt to identify the specific lens if multiple lenses have the same LensType
# Inputs: 0) PrintConv hash ref, 1) LensType, 2) ShortFocal, 3) LongFocal
#         4) MaxAperture, 5) LensModel
# Notes: PrintConv, LensType, ShortFocal and LongFocal must be defined.
#        Other inputs are optional.
sub PrintLensID(@)
{
    my ($printConv, $lensType, $shortFocal, $longFocal, $maxAperture, $lensModel) = @_;
    my $lens = $$printConv{$lensType};
    if ($lens) {
        # return this lens unless other lenses have the same LensType
        return LensWithTC($lens, $shortFocal) unless $$printConv{"$lensType.1"};
        $lens =~ s/ or .*//s;    # remove everything after "or"
        # make list of all possible matching lenses
        my @lenses = ( $lens );
        my $i;
        for ($i=1; $$printConv{"$lensType.$i"}; ++$i) {
            push @lenses, $$printConv{"$lensType.$i"};
        }
        # look for lens in user-defined lenses
        foreach $lens (@lenses) {
            next unless $Image::ExifTool::userLens{$lens};
            return LensWithTC($lens, $shortFocal);
        }
        # attempt to determine actual lens
        my ($tc, @maybe, @likely, @matches);
        foreach $tc (1, 1.4, 2, 2.8) {  # loop through teleconverter scaling factors
            foreach $lens (@lenses) {
                next unless $lens =~ /(\d+)(?:-(\d+))?mm.*?(?:[fF]\/?)(\d+(?:\.\d+)?)(?:-(\d+(?:\.\d+)?))?/;
                # ($1=short focal, $2=long focal, $3=max aperture wide, $4=max aperture tele)
                my ($sf, $lf, $sa, $la) = ($1, $2, $3, $4);
                # see if we can rule out this lens by focal length or aperture
                $lf = $sf if $sf and not $lf;
                $la = $sa if $sa and not $la;
                next if abs($shortFocal - $sf * $tc) > 0.9;
                my $tclens = $lens;
                $tclens .= " + ${tc}x" if $tc > 1;
                push @maybe, $tclens;
                next if abs($longFocal  - $lf * $tc) > 0.9;
                push @likely, $tclens;
                if ($maxAperture) {
                    # (not 100% sure that TC affects MaxAperture, but it should!)
                    next if $maxAperture < $sa * $tc - 0.15;
                    next if $maxAperture > $la * $tc + 0.15;
                }
                push @matches, $tclens;
            }
            last if @maybe;
        }
        return join(' or ', @matches) if @matches;
        return join(' or ', @likely) if @likely;
        return join(' or ', @maybe) if @maybe;
    } elsif ($lensModel and $lensModel =~ /\d/) {
        # use lens model as written by the camera (add "Canon" to the start
        # since the camera only understands Canon lenses anyway)
        return "Canon $lensModel";
    }
    my $str = '';
    if ($shortFocal) {
        $str .= sprintf(' %d', $shortFocal);
        $str .= sprintf('-%d', $longFocal) if $longFocal and $longFocal != $shortFocal;
        $str .= 'mm';
    }
    return "Unknown$str" if $lensType eq '-1'; # (careful because Sigma LensType's may not be integer)
    return "Unknown ($lensType)$str";
}

#------------------------------------------------------------------------------
# Swap 16-bit words in 32-bit integers
# Inputs: 0) string of integers
# Returns: string of word-swapped integers
sub SwapWords($)
{
    my @a = split(' ', shift);
    $_ = (($_ >> 16) | ($_ << 16)) & 0xffffffff foreach @a;
    return "@a";
}

#------------------------------------------------------------------------------
# Validate first word of Canon binary data
# Inputs: 0) data pointer, 1) offset, 2-N) list of valid values
# Returns: true if data value is the same
sub Validate($$@)
{
    my ($dataPt, $offset, @vals) = @_;
    # the first 16-bit value is the length of the data in bytes
    my $dataVal = Image::ExifTool::Get16u($dataPt, $offset);
    my $val;
    foreach $val (@vals) {
        return 1 if $val == $dataVal;
    }
    return undef;
}

#------------------------------------------------------------------------------
# Validate CanonAFInfo
# Inputs: 0) data pointer, 1) offset, 2) size
# Returns: true if data appears valid
sub ValidateAFInfo($$$)
{
    my ($dataPt, $offset, $size) = @_;
    return 0 if $size < 24; # must be at least 24 bytes long (PowerShot Pro1)
    my $af = Get16u($dataPt, $offset);
    return 0 if $af !~ /^(1|5|7|9|15|45|53)$/; # check NumAFPoints
    my $w1 = Get16u($dataPt, $offset + 4);
    my $h1 = Get16u($dataPt, $offset + 6);
    return 0 unless $h1 and $w1;
    my $f1 = $w1 / $h1;
    # check for normal aspect ratio
    return 1 if abs($f1 - 1.33) < 0.01 or abs($f1 - 1.67) < 0.01;
    # ZoomBrowser can modify this for rotated images (ref Joshua Bixby)
    return 1 if abs($f1 - 0.75) < 0.01 or abs($f1 - 0.60) < 0.01;
    my $w2 = Get16u($dataPt, $offset + 8);
    my $h2 = Get16u($dataPt, $offset + 10);
    return 0 unless $h2 and $w2;
    # compare aspect ratio with AF image size
    # (but the Powershot AFImageHeight is odd, hence the test above)
    return 0 if $w1 eq $h1;
    my $f2 = $w2 / $h2;
    return 1 if abs(1-$f1/$f2) < 0.01;
    return 1 if abs(1-$f1*$f2) < 0.01;
    return 0;
}

#------------------------------------------------------------------------------
# Read original decision data from file (variable length)
# Inputs: 0) ExifTool object ref, 1) offset in file
# Returns: reference to original decision data (or undef if no data)
sub ReadODD($$)
{
    my ($exifTool, $offset) = @_;
    return undef unless $offset;
    my ($raf, $buff, $buf2, $i, $warn);
    return undef unless defined($raf = $$exifTool{RAF});
    # the data block is a variable length and starts with 0xffffffff
    # followed a 4-byte (int32u) version number
    my $pos = $raf->Tell();
    if ($raf->Seek($offset, 0) and $raf->Read($buff, 8)==8 and $buff=~/^\xff{4}.\0\0/s) {
        my $err = 1;
        # must set byte order in case it is different than current byte order
        # (we could be reading this after byte order was changed)
        my $oldOrder = GetByteOrder();
        my $version = Get32u(\$buff, 4);
        if ($version > 20) {
            ToggleByteOrder();
            $version = unpack('N',pack('V',$version));
        }
        if ($version == 1 or   # 1Ds (big endian)
            $version == 2)     # 5D/20D (little endian)
        {
            # this data is structured as follows:
            #  4 bytes: all 0xff
            #  4 bytes: version number (=1 or 2)
            # 20 bytes: sha1
            #  4 bytes: record count
            # for each record:
            # |  4 bytes: record number (beginning at 0)
            # |  4 bytes: block offset
            # |  4 bytes: block length
            # | 20 bytes: block sha1
            if ($raf->Read($buf2, 24) == 24) {
                $buff .= $buf2;
                my $count = Get32u(\$buf2, 20);
                # read all records if the count is reasonable
                if ($count and $count < 20 and
                    $raf->Read($buf2, $count * 32) == $count * 32)
                {
                    $buff .= $buf2;
                    undef $err;
                }
            }
        } elsif ($version == 3) { # newer models (little endian)
            # this data is structured as follows:
            #  4 bytes: all 0xff
            #  4 bytes: version number (=3)
            # 24 bytes: sha1 A length (=20) + sha1 A
            # 24 bytes: sha1 B length (=20) + sha1 B
            #  4 bytes: length of remaining data (including this length word!)
            #  8 bytes: salt length (=4) + salt ?
            #  4 bytes: unknown (=3)
            #  4 bytes: size of file
            #  4 bytes: unknown (=1 for most models, 2 for 5DmkII)
            #  4 bytes: unknown (=1)
            #  4 bytes: unknown (always the same for a given firmware version)
            #  4 bytes: unknown (random)
            #  4 bytes: record count
            # for each record:
            # |  4 bytes: record number (beginning at 1)
            # |  8 bytes: salt length (=4) + salt ?
            # | 24 bytes: sha1 length (=20) + sha1
            # |  4 bytes: block count
            # | for each block:
            # | |  4 bytes: block offset
            # | |  4 bytes: block length
            # followed by zero padding to end of ODD data (~72 bytes)
            for ($i=0; ; ++$i) {
                $i == 3 and undef $err, last; # success!
                $raf->Read($buf2, 4) == 4 or last;
                $buff .= $buf2;
                my $len = Get32u(\$buf2, 0);
                # (the data length includes the length word itself - doh!)
                $len -= 4 if $i == 2 and $len >= 4;
                # make sure records are a reasonable size (<= 64kB)
                $len <= 0x10000 and $raf->Read($buf2, $len) == $len or last;
                $buff .= $buf2;
            }
        } else {
            $warn = "Unsupported original decision data version $version";
        }
        SetByteOrder($oldOrder);
        unless ($err) {
            if ($exifTool->Options('HtmlDump')) {
                $exifTool->HDump($offset, length $buff, '[OriginalDecisionData]', undef);
            }
            $raf->Seek($pos, 0);    # restore original file position
            return \$buff;
        }
    }
    $exifTool->Warn($warn || 'Invalid original decision data');
    $raf->Seek($pos, 0);    # restore original file position
    return undef;
}

#------------------------------------------------------------------------------
# Convert the CameraISO value
# Inputs: 0) value, 1) set for inverse conversion
sub CameraISO($;$)
{
    my ($val, $inv) = @_;
    my $rtnVal;
    my %isoLookup = (
         0 => 'n/a',
        14 => 'Auto High', #PH (S3IS)
        15 => 'Auto',
        16 => 50,
        17 => 100,
        18 => 200,
        19 => 400,
        20 => 800, #PH
    );
    if ($inv) {
        $rtnVal = Image::ExifTool::ReverseLookup($val, \%isoLookup);
        if (not defined $rtnVal and Image::ExifTool::IsInt($val)) {
            $rtnVal = ($val & 0x3fff) | 0x4000;
        }
    } elsif ($val != 0x7fff) {
        if ($val & 0x4000) {
            $rtnVal = $val & 0x3fff;
        } else {
            $rtnVal = $isoLookup{$val} || "Unknown ($val)";
        }
    }
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Print range of focal lengths
# Inputs: 0) short focal, 1) long focal, 2) optional scaling factor
sub PrintFocalRange(@)
{
    my ($short, $long, $scale) = @_;

    $scale or $scale = 1;
    if ($short == $long) {
        return sprintf("%.1f mm", $short * $scale);
    } else {
        return sprintf("%.1f - %.1f mm", $short * $scale, $long * $scale);
    }
}

#------------------------------------------------------------------------------
# Process a serial stream of binary data
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
# Notes: The tagID's for serial stream tags are consecutive indices beginning
#        at 0, and the corresponding values must be contiguous in memory.
#        "Unknown" tags must be used to skip padding or unknown values.
sub ProcessSerialData($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $offset = $$dirInfo{DirStart};
    my $size = $$dirInfo{DirLen};
    my $base = $$dirInfo{Base} || 0;
    my $verbose = $exifTool->Options('Verbose');
    my $dataPos = $$dirInfo{DataPos} || 0;

    # temporarily set Unknown option so GetTagInfo() will return existing unknown tags
    # (require to maintain serial data synchronization)
    my $unknown = $exifTool->Options(Unknown => 1);
    # but disable unknown tag generation (because processing ends when we run out of tags)
    $$exifTool{NO_UNKNOWN} = 1;

    $verbose and $exifTool->VerboseDir('SerialData', undef, $size);

    # get default format ('int8u' unless specified)
    my $defaultFormat = $$tagTablePtr{FORMAT} || 'int8u';

    my ($index, %val);
    my $pos = 0;
    for ($index=0; $$tagTablePtr{$index} and $pos <= $size; ++$index) {
        my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, $index) or last;
        my $format = $$tagInfo{Format};
        my $count = 1;
        if ($format) {
            if ($format =~ /(.*)\[(.*)\]/) {
                $format = $1;
                $count = $2;
                # evaluate count to allow count to be based on previous values
                #### eval Format (%val, $size)
                $count = eval $count;
                $@ and warn("Format $$tagInfo{Name}: $@"), last;
            } elsif ($format eq 'string') {
                # allow string with no specified count to run to end of block
                $count = ($size > $pos) ? $size - $pos : 0;
            }
        } else {
            $format = $defaultFormat;
        }
        my $len = (Image::ExifTool::FormatSize($format) || 1) * $count;
        last if $pos + $len > $size;
        my $val = ReadValue($dataPt, $pos+$offset, $format, $count, $size-$pos);
        last unless defined $val;
        if ($verbose) {
            $exifTool->VerboseInfo($index, $tagInfo,
                Index  => $index,
                Table  => $tagTablePtr,
                Value  => $val,
                DataPt => $dataPt,
                Size   => $len,
                Start  => $pos+$offset,
                Addr   => $pos+$offset+$base+$dataPos,
                Format => $format,
                Count  => $count,
            );
        }
        $val{$index} = $val;
        if ($$tagInfo{SubDirectory}) {
            my $subTablePtr = GetTagTable($tagInfo->{SubDirectory}->{TagTable});
            my %dirInfo = (
                DataPt => \$val,
                DataPos => $dataPos + $pos,
                DirStart => 0,
                DirLen => length($val),
            );
            $exifTool->ProcessDirectory(\%dirInfo, $subTablePtr);
        } elsif (not $$tagInfo{Unknown} or $unknown) {
            # don't extract zero-length information
            $exifTool->FoundTag($tagInfo, $val) if $count;
        }
        $pos += $len;
    }
    $exifTool->Options(Unknown => $unknown);    # restore Unknown option
    delete $$exifTool{NO_UNKNOWN};
    return 1;
}

#------------------------------------------------------------------------------
# Print 1D AF points
# Inputs: 0) value to convert
# Focus point pattern:
#            A1  A2  A3  A4  A5  A6  A7
#      B1  B2  B3  B4  B5  B6  B7  B8  B9  B10
#    C1  C2  C3  C4  C5  C6  C7  C9  C9  C10  C11
#      D1  D2  D3  D4  D5  D6  D7  D8  D9  D10
#            E1  E2  E3  E4  E5  E6  E7
sub PrintAFPoints1D($)
{
    my $val = shift;
    return 'Unknown' unless length $val == 8;
    # list of focus point values for decoding the first byte of the 8-byte record.
    # they are the x/y positions of each bit in the AF point mask
    # (y is upper 3 bits / x is lower 5 bits)
    my @focusPts = (0,0,
              0x04,0x06,0x08,0x0a,0x0c,0x0e,0x10,         0,0,
      0x21,0x23,0x25,0x27,0x29,0x2b,0x2d,0x2f,0x31,0x33,
    0x40,0x42,0x44,0x46,0x48,0x4a,0x4c,0x4d,0x50,0x52,0x54,
      0x61,0x63,0x65,0x67,0x69,0x6b,0x6d,0x6f,0x71,0x73,  0,0,
              0x84,0x86,0x88,0x8a,0x8c,0x8e,0x90,   0,0,0,0,0
    );
    my $focus = unpack('C',$val);
    my @bits = split //, unpack('b*',substr($val,1));
    my @rows = split //, '  AAAAAAA  BBBBBBBBBBCCCCCCCCCCCDDDDDDDDDD  EEEEEEE     ';
    my ($focusing, $focusPt, @points);
    my $lastRow = '';
    my $col = 0;
    foreach $focusPt (@focusPts) {
        my $row = shift @rows;
        $col = ($row eq $lastRow) ? $col + 1 : 1;
        $lastRow = $row;
        $focusing = "$row$col" if $focus eq $focusPt;
        push @points, "$row$col" if shift @bits;
    }
    $focusing or $focusing = ($focus eq 0xff) ? 'Auto' : sprintf('Unknown (0x%.2x)',$focus);
    return "$focusing (" . join(',',@points) . ')';
}

#------------------------------------------------------------------------------
# Convert Canon hex-based EV (modulo 0x20) to real number
# Inputs: 0) value to convert
# ie) 0x00 -> 0
#     0x0c -> 0.33333
#     0x10 -> 0.5
#     0x14 -> 0.66666
#     0x20 -> 1   ...  etc
sub CanonEv($)
{
    my $val = shift;
    my $sign;
    # temporarily make the number positive
    if ($val < 0) {
        $val = -$val;
        $sign = -1;
    } else {
        $sign = 1;
    }
    my $frac = $val & 0x1f;
    $val -= $frac;      # remove fraction
    # Convert 1/3 and 2/3 codes
    if ($frac == 0x0c) {
        $frac = 0x20 / 3;
    } elsif ($frac == 0x14) {
        $frac = 0x40 / 3;
    }
    return $sign * ($val + $frac) / 0x20;
}

#------------------------------------------------------------------------------
# Convert number to Canon hex-based EV (modulo 0x20)
# Inputs: 0) number
# Returns: Canon EV code
sub CanonEvInv($)
{
    my $num = shift;
    my $sign;
    # temporarily make the number positive
    if ($num < 0) {
        $num = -$num;
        $sign = -1;
    } else {
        $sign = 1;
    }
    my $val = int($num);
    my $frac = $num - $val;
    if (abs($frac - 0.33) < 0.05) {
        $frac = 0x0c
    } elsif (abs($frac - 0.67) < 0.05) {
        $frac = 0x14;
    } else {
        $frac = int($frac * 0x20 + 0.5);
    }
    return $sign * ($val * 0x20 + $frac);
}

#------------------------------------------------------------------------------
# Process a creative filter data
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessFilters($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $pos = $$dirInfo{DirStart};
    my $dirLen = $$dirInfo{DirLen};
    my $dataPos = $$dirInfo{DataPos} || 0;
    my $end = $pos + $dirLen;
    my $verbose = $exifTool->Options('Verbose');

    return 0 if $dirLen < 8;
    my $numFilters = Get32u($dataPt, $pos + 4);
    $verbose and $exifTool->VerboseDir('Creative Filter', $numFilters);
    $pos += 8;
    my ($i, $j, $err);
    for ($i=0; $i<$numFilters; ++$i) {
        # read filter structure:
        # 4 bytes - filter number
        # 4 bytes - filter data length
        # 4 bytes - number of parameters:
        # |  4 bytes - paramter ID
        # |  4 bytes - paramter value count
        # |  4 bytes * count - paramter values (NC)
        $pos + 12 > $end and $err = "Truncated data for filter $i", last;
        my $fnum = Get32u($dataPt, $pos); # (is this an index or an ID?)
        my $size = Get32u($dataPt, $pos + 4);
        my $nparm = Get32u($dataPt, $pos + 8);
        my $nxt = $pos + 4 + $size;
        $nxt > $end and $err = "Invalid size ($size) for filter $i", last;
        $verbose and $exifTool->VerboseDir("Filter $fnum", $nparm, $size);
        $pos += 12;
        for ($j=0; $j<$nparm; ++$j) {
            $pos + 12 > $end and $err = "Truncated data for filter $i param $j", last;
            my $tag = Get32u($dataPt, $pos);
            my $count = Get32u($dataPt, $pos + 4);
            $pos += 8;
            $pos + 4 * $count > $end and $err = "Truncated value for filter $i param $j", last;
            my $val = ReadValue($dataPt, $pos, 'int32s', $count, 4 * $count);
            $exifTool->HandleTag($tagTablePtr, $tag, $val,
                DataPt  => $dataPt,
                DataPos => $dataPos,
                Start   => $pos,
                Size    => 4 * $count,
            );
            $pos += 4 * $count;
        }
        $pos = $nxt;    # step to next filter
    }
    $err and $exifTool->Warn($err, 1);
    return 1;
}

#------------------------------------------------------------------------------
# Write Canon maker notes
# Inputs: 0) ExifTool object reference, 1) dirInfo ref, 2) tag table ref
# Returns: data block (may be empty if no Exif data) or undef on error
sub WriteCanon($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    $exifTool or return 1;    # allow dummy access to autoload this package
    my $dirData = Image::ExifTool::Exif::WriteExif($exifTool, $dirInfo, $tagTablePtr);
    # add footer which is written by some Canon models (format of a TIFF header)
    if (defined $dirData and length $dirData and $$dirInfo{Fixup}) {
        $dirData .= GetByteOrder() . Set16u(42) . Set32u(0);
        $dirInfo->{Fixup}->AddFixup(length($dirData) - 4);
    }
    return $dirData;
}

#------------------------------------------------------------------------------
1;  # end

__END__

=head1 NAME

Image::ExifTool::Canon - Canon EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Canon maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2011, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html>

=item L<http://www.wonderland.org/crw/>

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=item L<http://homepage3.nifty.com/kamisaka/makernote/makernote_canon.htm>

=item (...plus lots of testing with my 300D and my daughter's A570IS!)

=back

=head1 ACKNOWLEDGEMENTS

Thanks Michael Rommel and Daniel Pittman for information they provided about
the Digital Ixus and PowerShot S70 cameras, Juha Eskelinen and Emil Sit for
figuring out the 20D and 30D FileNumber, Denny Priebe for figuring out a
couple of 1D tags, and Michael Tiemann, Rainer Honle, Dave Nicholson, Chris
Huebsch, Ger Vermeulen, Darryl Zurn, D.J. Cristi, Bogdan and Vesa Kivisto for
decoding a number of new tags.  Also thanks to everyone who made contributions
to the LensType lookup list or the meanings of other tag values.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Canon Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
