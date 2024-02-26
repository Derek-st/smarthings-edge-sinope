local capabilities = require "st.capabilities"
local data_types = require "st.zigbee.data_types"
local utils = require "st.utils"
local log = require "log"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local json = require "dkjson"


local function dumpi(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dumpi(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end


local function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dumpi(v) .. ',\n'
      end
      return s .. '} '
   else
      return tostring(o)
   end
end



local common = {}

local INTERIM_XYZ = "interim_xyz"

common.MFG_CLUSTER = 0xFC02
common.SINOPE_CLUSTER = 0xFF01

common.MFG_CODES = {
    SmartThings = 0x110A,
    Centralite = 0x104E
}
common.MFG_CODES['Sinope Technologies' ] =  0x4508



local jsoncoeff = [[{
  "M40" : { "0.0" : 1.1459, "0.1": 1.1459,"0.2": 1.1459, "0.3": 1.1459, "0.4": 1.1459,"0.5": 1.1459,"0.6": 1.1459,"0.7": 1.1459,"0.8": 1.1459,"0.9": 1.1459 },
  "M39" : { "0" : 1.1435, "0.1": 1.1437, "0.2": 1.144, "0.3": 1.1442, "0.4": 1.1445, "0.5": 1.1447, "0.6": 1.1449, "0.7": 1.1452, "0.8": 1.1454, "0.9": 1.1457},
  "M38": { "0.0" : 1.1411, "0.1": 1.1413, "0.2": 1.1416, "0.3": 1.1418, "0.4": 1.142, "0.5": 1.1423, "0.6": 1.1425, "0.7": 1.1428, "0.8": 1.143, "0.9": 1.1432},
  "M37": { "0.0" : 1.1387, "0.1": 1.1389, "0.2": 1.1391, "0.3": 1.1394, "0.4": 1.1396, "0.5": 1.1399, "0.6": 1.1401, "0.7": 1.1404, "0.8": 1.1406, "0.9": 1.1408},
  "M36": { "0.0" : 1.1362, "0.1": 1.1365, "0.2": 1.1367, "0.3": 1.137, "0.4": 1.1372, "0.5": 1.1374, "0.6": 1.1377, "0.7": 1.1379, "0.8": 1.1382, "0.9": 1.1384},
  "M35": { "0.0" : 1.1338, "0.1": 1.134, "0.2": 1.1343, "0.3": 1.1345, "0.4": 1.1348, "0.5": 1.135, "0.6": 1.1353, "0.7": 1.1355, "0.8": 1.1357, "0.9": 1.136},
  "M34": { "0.0" : 1.1314, "0.1": 1.1316, "0.2": 1.1319, "0.3": 1.1321, "0.4": 1.1323, "0.5": 1.1326, "0.6": 1.1328, "0.7": 1.1331, "0.8": 1.1333, "0.9": 1.1336},
  "M33": { "0.0" : 1.1289, "0.1": 1.1292, "0.2": 1.1294, "0.3": 1.1297, "0.4": 1.1299, "0.5": 1.1301, "0.6": 1.1304, "0.7": 1.1306, "0.8": 1.1309, "0.9": 1.1311},
  "M32": { "0.0" : 1.1265, "0.1": 1.1267, "0.2": 1.127, "0.3": 1.1272, "0.4": 1.1274, "0.5": 1.1277, "0.6": 1.1279, "0.7": 1.1282, "0.8": 1.1284, "0.9": 1.1287},
  "M31": { "0.0" : 1.124, "0.1": 1.1242, "0.2": 1.1245, "0.3": 1.1247, "0.4": 1.125, "0.5": 1.1252, "0.6": 1.1255, "0.7": 1.1257, "0.8": 1.126, "0.9": 1.1262},
  "M30": { "0.0" : 1.1215, "0.1": 1.1218, "0.2": 1.122, "0.3": 1.1223, "0.4": 1.1225, "0.5": 1.1228, "0.6": 1.123, "0.7": 1.1233, "0.8": 1.1235, "0.9": 1.1238},
  "M29": { "0.0" : 1.1191, "0.1": 1.1193, "0.2": 1.1196, "0.3": 1.1198, "0.4": 1.12, "0.5": 1.1203, "0.6": 1.1205, "0.7": 1.1208, "0.8": 1.121, "0.9": 1.1213},
  "M28": { "0.0" : 1.1166, "0.1": 1.1168, "0.2": 1.1171, "0.3": 1.1173, "0.4": 1.1176, "0.5": 1.1178, "0.6": 1.1181, "0.7": 1.1183, "0.8": 1.1186, "0.9": 1.1188},
  "M27": { "0.0" : 1.1141, "0.1": 1.1143, "0.2": 1.1146, "0.3": 1.1148, "0.4": 1.1151, "0.5": 1.1153, "0.6": 1.1156, "0.7": 1.1158, "0.8": 1.1161, "0.9": 1.1163},
  "M26": { "0.0" : 1.1116, "0.1": 1.1118, "0.2": 1.1121, "0.3": 1.1123, "0.4": 1.1126, "0.5": 1.1128, "0.6": 1.1131, "0.7": 1.1133, "0.8": 1.1136, "0.9": 1.1138},
  "M25": { "0.0" : 1.1091, "0.1": 1.1093, "0.2": 1.1096, "0.3": 1.1098, "0.4": 1.1101, "0.5": 1.1103, "0.6": 1.1106, "0.7": 1.1108, "0.8": 1.1111, "0.9": 1.1113},
  "M24": { "0.0" : 1.1065, "0.1": 1.1068, "0.2": 1.1071, "0.3": 1.1073, "0.4": 1.1076, "0.5": 1.1078, "0.6": 1.1081, "0.7": 1.1083, "0.8": 1.1086, "0.9": 1.1088},
  "M23": { "0.0" : 1.104, "0.1": 1.1043, "0.2": 1.1045, "0.3": 1.1048, "0.4": 1.105, "0.5": 1.1053, "0.6": 1.1055, "0.7": 1.1058, "0.8": 1.106, "0.9": 1.1063},
  "M22": { "0.0" : 1.1015, "0.1": 1.1017, "0.2": 1.102, "0.3": 1.1022, "0.4": 1.1025, "0.5": 1.1028, "0.6": 1.103, "0.7": 1.1033, "0.8": 1.1035, "0.9": 1.1038},
  "M21": { "0.0" : 1.0989, "0.1": 1.0992, "0.2": 1.0995, "0.3": 1.0997, "0.4": 1.1, "0.5": 1.1002, "0.6": 1.1005, "0.7": 1.1007, "0.8": 1.101, "0.9": 1.1012},
  "M20": { "0.0" : 1.0964, "0.1": 1.0966, "0.2": 1.0969, "0.3": 1.0972, "0.4": 1.0974, "0.5": 1.0977, "0.6": 1.0979, "0.7": 1.0982, "0.8": 1.0984, "0.9": 1.0987},
  "M19": { "0.0" : 1.0938, "0.1": 1.0941, "0.2": 1.0943, "0.3": 1.0946, "0.4": 1.0949, "0.5": 1.0951, "0.6": 1.0954, "0.7": 1.0956, "0.8": 1.0959, "0.9": 1.0961},
  "M18": { "0.0" : 1.0913, "0.1": 1.0915, "0.2": 1.0918, "0.3": 1.092, "0.4": 1.0923, "0.5": 1.0925, "0.6": 1.0928, "0.7": 1.0931, "0.8": 1.0933, "0.9": 1.0936},
  "M17": { "0.0" : 1.0887, "0.1": 1.0889, "0.2": 1.0892, "0.3": 1.0895, "0.4": 1.0897, "0.5": 1.09, "0.6": 1.0902, "0.7": 1.0905, "0.8": 1.0907, "0.9": 1.091},
  "M16": { "0.0" : 1.0861, "0.1": 1.0863, "0.2": 1.0866, "0.3": 1.0869, "0.4": 1.0871, "0.5": 1.0874, "0.6": 1.0876, "0.7": 1.0879, "0.8": 1.0882, "0.9": 1.0884},
  "M15": { "0.0" : 1.0835, "0.1": 1.0837, "0.2": 1.084, "0.3": 1.0843, "0.4": 1.0845, "0.5": 1.0848, "0.6": 1.085, "0.7": 1.0853, "0.8": 1.0856, "0.9": 1.0858},
  "M14": { "0.0" : 1.0809, "0.1": 1.0811, "0.2": 1.0814, "0.3": 1.0817, "0.4": 1.0819, "0.5": 1.0822, "0.6": 1.0824, "0.7": 1.0827, "0.8": 1.083, "0.9": 1.0832},
  "M13": { "0.0" : 1.0783, "0.1": 1.0785, "0.2": 1.0788, "0.3": 1.079, "0.4": 1.0793, "0.5": 1.0796, "0.6": 1.0798, "0.7": 1.0801, "0.8": 1.0804, "0.9": 1.0806},
  "M12": { "0.0" : 1.0756, "0.1": 1.0759, "0.2": 1.0762, "0.3": 1.0764, "0.4": 1.0767, "0.5": 1.0769, "0.6": 1.0772, "0.7": 1.0775, "0.8": 1.0777, "0.9": 1.078},
  "M11": { "0.0" : 1.073, "0.1": 1.0732, "0.2": 1.0735, "0.3": 1.0738, "0.4": 1.074, "0.5": 1.0743, "0.6": 1.0746, "0.7": 1.0748, "0.8": 1.0751, "0.9": 1.0754},
  "M10": { "0.0" : 1.0703, "0.1": 1.0706, "0.2": 1.0709, "0.3": 1.0711, "0.4": 1.0714, "0.5": 1.0717, "0.6": 1.0719, "0.7": 1.0722, "0.8": 1.0725, "0.9": 1.0727},
  "M9": { "0.0" : 1.0677, "0.1": 1.0679, "0.2": 1.0682, "0.3": 1.0685, "0.4": 1.0687, "0.5": 1.069, "0.6": 1.0693, "0.7": 1.0695, "0.8": 1.0698, "0.9": 1.0701},
  "M8": { "0.0" : 1.065, "0.1": 1.0653, "0.2": 1.0655, "0.3": 1.0658, "0.4": 1.0661, "0.5": 1.0663, "0.6": 1.0666, "0.7": 1.0669, "0.8": 1.0671, "0.9": 1.0674},
  "M7": { "0.0" : 1.0623, "0.1": 1.0626, "0.2": 1.0629, "0.3": 1.0631, "0.4": 1.0634, "0.5": 1.0637, "0.6": 1.0639, "0.7": 1.0642, "0.8": 1.0645, "0.9": 1.0647},
  "M6": { "0.0" : 1.0596, "0.1": 1.0599, "0.2": 1.0602, "0.3": 1.0604, "0.4": 1.0607, "0.5": 1.061, "0.6": 1.0612, "0.7": 1.0615, "0.8": 1.0618, "0.9": 1.062},
  "M5": { "0.0" : 1.0569, "0.1": 1.0572, "0.2": 1.0575, "0.3": 1.0577, "0.4": 1.058, "0.5": 1.0583, "0.6": 1.0585, "0.7": 1.0588, "0.8": 1.0591, "0.9": 1.0593},
  "M4": { "0.0" : 1.0542, "0.1": 1.0545, "0.2": 1.0547, "0.3": 1.055, "0.4": 1.0553, "0.5": 1.0556, "0.6": 1.0558, "0.7": 1.0561, "0.8": 1.0564, "0.9": 1.0566},
  "M3": { "0.0" : 1.0515, "0.1": 1.0517, "0.2": 1.052, "0.3": 1.0523, "0.4": 1.0526, "0.5": 1.0528, "0.6": 1.0531, "0.7": 1.0534, "0.8": 1.0536, "0.9": 1.0539},
  "M2": { "0.0" : 1.0487, "0.1": 1.049, "0.2": 1.0493, "0.3": 1.0495, "0.4": 1.0498, "0.5": 1.0501, "0.6": 1.0504, "0.7": 1.0506, "0.8": 1.0509, "0.9": 1.0512},
  "M1": { "0.0" : 1.046, "0.1": 1.0462, "0.2": 1.0465, "0.3": 1.0468, "0.4": 1.0471, "0.5": 1.0473, "0.6": 1.0476, "0.7": 1.0479, "0.8": 1.0482, "0.9": 1.0484},
  "M0" : { "0.0" : 1.046, "0.1": 1.0435, "0.2": 1.0438, "0.3": 1.0440, "0.4": 1.0443, "0.5": 1.0446, "0.6": 1.0449, "0.7": 1.0451, "0.8": 1.0454, "0.9": 1.0457},
  "0": { "0.0" : 1.0432, "0.1": 1.0435, "0.2": 1.0438, "0.3": 1.044, "0.4": 1.0443, "0.5": 1.0446, "0.6": 1.0449, "0.7": 1.0451, "0.8": 1.0454, "0.9": 1.0457},
  "1": { "0.0" : 1.0404, "0.1": 1.0401, "0.2": 1.0399, "0.3": 1.0396, "0.4": 1.0393, "0.5": 1.039, "0.6": 1.0387, "0.7": 1.0385, "0.8": 1.0382, "0.9": 1.0379},
  "2": { "0.0" : 1.0376, "0.1": 1.0373, "0.2": 1.0371, "0.3": 1.0368, "0.4": 1.0365, "0.5": 1.0362, "0.6": 1.0359, "0.7": 1.0357, "0.8": 1.0354, "0.9": 1.0351},
  "3": { "0.0" : 1.0348, "0.1": 1.0345, "0.2": 1.0343, "0.3": 1.034, "0.4": 1.0337, "0.5": 1.0334, "0.6": 1.0331, "0.7": 1.0328, "0.8": 1.0326, "0.9": 1.0323},
  "4": { "0.0" : 1.032, "0.1": 1.0317, "0.2": 1.0314, "0.3": 1.0311, "0.4": 1.0309, "0.5": 1.0306, "0.6": 1.0303, "0.7": 1.03, "0.8": 1.0297, "0.9": 1.0294},
  "5": { "0.0" : 1.0292, "0.1": 1.0289, "0.2": 1.0286, "0.3": 1.0283, "0.4": 1.028, "0.5": 1.0277, "0.6": 1.0275, "0.7": 1.0272, "0.8": 1.0269, "0.9": 1.0266},
  "6": { "0.0" : 1.0263, "0.1": 1.026, "0.2": 1.0257, "0.3": 1.0255, "0.4": 1.0252, "0.5": 1.0249, "0.6": 1.0246, "0.7": 1.0243, "0.8": 1.024, "0.9": 1.0237},
  "7": { "0.0" : 1.0235, "0.1": 1.0232, "0.2": 1.0229, "0.3": 1.0226, "0.4": 1.0223, "0.5": 1.022, "0.6": 1.0217, "0.7": 1.0214, "0.8": 1.0212, "0.9": 1.0209},
  "8": { "0.0" : 1.0206, "0.1": 1.0203, "0.2": 1.02, "0.3": 1.0197, "0.4": 1.0194, "0.5": 1.0191, "0.6": 1.0188, "0.7": 1.0186, "0.8": 1.0183, "0.9": 1.018},
  "9": { "0.0" : 1.0177, "0.1": 1.0174, "0.2": 1.0171, "0.3": 1.0168, "0.4": 1.0165, "0.5": 1.0162, "0.6": 1.0159, "0.7": 1.0156, "0.8": 1.0154, "0.9": 1.0151},
  "10": { "0.0" : 1.0148, "0.1": 1.0145, "0.2": 1.0142, "0.3": 1.0139, "0.4": 1.0136, "0.5": 1.0133, "0.6": 1.013, "0.7": 1.0127, "0.8": 1.0124, "0.9": 1.0121},
  "11": { "0.0" : 1.0119, "0.1": 1.0116, "0.2": 1.0113, "0.3": 1.011, "0.4": 1.0107, "0.5": 1.0104, "0.6": 1.0101, "0.7": 1.0098, "0.8": 1.0095, "0.9": 1.0092},
  "12": { "0.0" : 1.0089, "0.1": 1.0086, "0.2": 1.0083, "0.3": 1.008, "0.4": 1.0077, "0.5": 1.0074, "0.6": 1.0071, "0.7": 1.0068, "0.8": 1.0066, "0.9": 1.0063},
  "13": { "0.0" : 1.006, "0.1": 1.0057, "0.2": 1.0054, "0.3": 1.0051, "0.4": 1.0048, "0.5": 1.0045, "0.6": 1.0042, "0.7": 1.0039, "0.8": 1.0036, "0.9": 1.0033},
  "14": { "0.0" : 1.003, "0.1": 1.0027, "0.2": 1.0024, "0.3": 1.0021, "0.4": 1.0018, "0.5": 1.0015, "0.6": 1.0012, "0.7": 1.0009, "0.8": 1.0006, "0.9": 1.0003},
  "15": { "0.0" : 1, "0.1": 0.9997, "0.2": 0.9994, "0.3": 0.9991, "0.4": 0.9988, "0.5": 0.9985, "0.6": 0.9982, "0.7": 0.9979, "0.8": 0.9976, "0.9": 0.9973},
  "16": { "0.0" : 0.997, "0.1": 0.9967, "0.2": 0.9964, "0.3": 0.9961, "0.4": 0.9958, "0.5": 0.9955, "0.6": 0.9952, "0.7": 0.9949, "0.8": 0.9946, "0.9": 0.9943},
  "17": { "0.0" : 0.994, "0.1": 0.9937, "0.2": 0.9934, "0.3": 0.9931, "0.4": 0.9928, "0.5": 0.9925, "0.6": 0.9921, "0.7": 0.9918, "0.8": 0.9915, "0.9": 0.9912},
  "18": { "0.0" : 0.9909, "0.1": 0.9906, "0.2": 0.9903, "0.3": 0.99, "0.4": 0.9897, "0.5": 0.9894, "0.6": 0.9891, "0.7": 0.9888, "0.8": 0.9885, "0.9": 0.9882},
  "19": { "0.0" : 0.9879, "0.1": 0.9876, "0.2": 0.9873, "0.3": 0.987, "0.4": 0.9866, "0.5": 0.9863, "0.6": 0.986, "0.7": 0.9857, "0.8": 0.9854, "0.9": 0.9851},
  "20": { "0.0" : 0.9848, "0.1": 0.9845, "0.2": 0.9842, "0.3": 0.9839, "0.4": 0.9836, "0.5": 0.9832, "0.6": 0.9829, "0.7": 0.9826, "0.8": 0.9823, "0.9": 0.982},
  "21": { "0.0" : 0.9817, "0.1": 0.9814, "0.2": 0.9811, "0.3": 0.9808, "0.4": 0.9805, "0.5": 0.9801, "0.6": 0.9798, "0.7": 0.9795, "0.8": 0.9792, "0.9": 0.9789},
  "22": { "0.0" : 0.9786, "0.1": 0.9783, "0.2": 0.978, "0.3": 0.9776, "0.4": 0.9773, "0.5": 0.977, "0.6": 0.9767, "0.7": 0.9764, "0.8": 0.9761, "0.9": 0.9758},
  "23": { "0.0" : 0.9754, "0.1": 0.9751, "0.2": 0.9748, "0.3": 0.9745, "0.4": 0.9742, "0.5": 0.9739, "0.6": 0.9736, "0.7": 0.9732, "0.8": 0.9729, "0.9": 0.9726},
  "24": { "0.0" : 0.9723, "0.1": 0.972, "0.2": 0.9717, "0.3": 0.9713, "0.4": 0.971, "0.5": 0.9707, "0.6": 0.9704, "0.7": 0.9701, "0.8": 0.9697, "0.9": 0.9694},
  "25": { "0.0" : 0.9691, "0.1": 0.9688, "0.2": 0.9685, "0.3": 0.9681, "0.4": 0.9678, "0.5": 0.9675, "0.6": 0.9672, "0.7": 0.9669, "0.8": 0.9665, "0.9": 0.9662},
  "26": { "0.0" : 0.9659, "0.1": 0.9656, "0.2": 0.9653, "0.3": 0.9649, "0.4": 0.9646, "0.5": 0.9643, "0.6": 0.964, "0.7": 0.9637, "0.8": 0.9633, "0.9": 0.963},
  "27": { "0.0" : 0.9627, "0.1": 0.9624, "0.2": 0.962, "0.3": 0.9617, "0.4": 0.9614, "0.5": 0.9611, "0.6": 0.9607, "0.7": 0.9604, "0.8": 0.9601, "0.9": 0.9598},
  "28": { "0.0" : 0.9594, "0.1": 0.9591, "0.2": 0.9588, "0.3": 0.9585, "0.4": 0.9581, "0.5": 0.9578, "0.6": 0.9575, "0.7": 0.9572, "0.8": 0.9568, "0.9": 0.9565},
  "29": { "0.0" : 0.9562, "0.1": 0.9558, "0.2": 0.9555, "0.3": 0.9552, "0.4": 0.9549, "0.5": 0.9545, "0.6": 0.9542, "0.7": 0.9539, "0.8": 0.9535, "0.9": 0.9532},
  "30": { "0.0" : 0.9529, "0.1": 0.9525, "0.2": 0.9522, "0.3": 0.9519, "0.4": 0.9516, "0.5": 0.9512, "0.6": 0.9509, "0.7": 0.9506, "0.8": 0.9502, "0.9": 0.9499},
  "31": { "0.0" : 0.9496, "0.1": 0.9492, "0.2": 0.9489, "0.3": 0.9486, "0.4": 0.9482, "0.5": 0.9479, "0.6": 0.9476, "0.7": 0.9472, "0.8": 0.9469, "0.9": 0.9466},
  "32": { "0.0" : 0.9462, "0.1": 0.9459, "0.2": 0.9455, "0.3": 0.9452, "0.4": 0.9449, "0.5": 0.9445, "0.6": 0.9442, "0.7": 0.9439, "0.8": 0.9435, "0.9": 0.9432},
  "33": { "0.0" : 0.9429, "0.1": 0.9425, "0.2": 0.9422, "0.3": 0.9418, "0.4": 0.9415, "0.5": 0.9412, "0.6": 0.9408, "0.7": 0.9405, "0.8": 0.9401, "0.9": 0.9398},
  "34": { "0.0" : 0.9395, "0.1": 0.9391, "0.2": 0.9388, "0.3": 0.9384, "0.4": 0.9381, "0.5": 0.9377, "0.6": 0.9374, "0.7": 0.9371, "0.8": 0.9367, "0.9": 0.9364},
  "35": { "0.0" : 0.936, "0.1": 0.9357, "0.2": 0.9353, "0.3": 0.935, "0.4": 0.9347, "0.5": 0.9343, "0.6": 0.934, "0.7": 0.9336, "0.8": 0.9333, "0.9": 0.9329},
  "36": { "0.0" : 0.9326, "0.1": 0.9322, "0.2": 0.9319, "0.3": 0.9315, "0.4": 0.9312, "0.5": 0.9309, "0.6": 0.9305, "0.7": 0.9302, "0.8": 0.9298, "0.9": 0.9295},
  "37": { "0.0" : 0.9291, "0.1": 0.9288, "0.2": 0.9284, "0.3": 0.9281, "0.4": 0.9277, "0.5": 0.9274, "0.6": 0.927, "0.7": 0.9267, "0.8": 0.9263, "0.9": 0.926},
  "38": { "0.0" : 0.9256, "0.1": 0.9252, "0.2": 0.9249, "0.3": 0.9245, "0.4": 0.9242, "0.5": 0.9238, "0.6": 0.9235, "0.7": 0.9231, "0.8": 0.9228, "0.9": 0.9224},
  "39": { "0.0" : 0.9221, "0.1": 0.9217, "0.2": 0.9214, "0.3": 0.921, "0.4": 0.9206, "0.5": 0.9203, "0.6": 0.9199, "0.7": 0.9196, "0.8": 0.9192, "0.9": 0.9189},
  "40": { "0.0" : 0.9185, "0.1": 0.9181, "0.2": 0.9178, "0.3": 0.9174, "0.4": 0.9171, "0.5": 0.9167, "0.6": 0.9163, "0.7": 0.916, "0.8": 0.9156, "0.9": 0.9153},
  "41": { "0.0" : 0.9149, "0.1": 0.9145, "0.2": 0.9142, "0.3": 0.9138, "0.4": 0.9134, "0.5": 0.9131, "0.6": 0.9127, "0.7": 0.9123, "0.8": 0.912, "0.9": 0.9116},
  "42": { "0.0" : 0.9113, "0.1": 0.9109, "0.2": 0.9105, "0.3": 0.9102, "0.4": 0.9098, "0.5": 0.9094, "0.6": 0.9091, "0.7": 0.9087, "0.8": 0.9083, "0.9": 0.908},
  "43": { "0.0" : 0.9076, "0.1": 0.9072, "0.2": 0.9068, "0.3": 0.9065, "0.4": 0.9061, "0.5": 0.9057, "0.6": 0.9054, "0.7": 0.905, "0.8": 0.9046, "0.9": 0.9043},
  "44": { "0.0" : 0.9039, "0.1": 0.9035, "0.2": 0.9031, "0.3": 0.9028, "0.4": 0.9024, "0.5": 0.902, "0.6": 0.9016, "0.7": 0.9013, "0.8": 0.9009, "0.9": 0.9005},
  "45": { "0.0" : 0.9001, "0.1": 0.8998, "0.2": 0.8994, "0.3": 0.899, "0.4": 0.8986, "0.5": 0.8983, "0.6": 0.8979, "0.7": 0.8975, "0.8": 0.8971, "0.9": 0.8967},
  "46": { "0.0" : 0.8964, "0.1": 0.896, "0.2": 0.8956, "0.3": 0.8952, "0.4": 0.8948, "0.5": 0.8945, "0.6": 0.8941, "0.7": 0.8937, "0.8": 0.8933, "0.9": 0.8929},
  "47": { "0.0" : 0.8925, "0.1": 0.8922, "0.2": 0.8918, "0.3": 0.8914, "0.4": 0.891, "0.5": 0.8906, "0.6": 0.8902, "0.7": 0.8898, "0.8": 0.8895, "0.9": 0.8891},
  "48": { "0.0" : 0.8887, "0.1": 0.8883, "0.2": 0.8879, "0.3": 0.8875, "0.4": 0.8871, "0.5": 0.8867, "0.6": 0.8863, "0.7": 0.886, "0.8": 0.8856, "0.9": 0.8852},
  "49": { "0.0" : 0.8848, "0.1": 0.8844, "0.2": 0.884, "0.3": 0.8836, "0.4": 0.8832, "0.5": 0.8828, "0.6": 0.8824, "0.7": 0.882, "0.8": 0.8816, "0.9": 0.8812},
  "50": { "0.0" : 0.8808, "0.1": 0.8804, "0.2": 0.88, "0.3": 0.8796, "0.4": 0.8792, "0.5": 0.8788, "0.6": 0.8785, "0.7": 0.8781, "0.8": 0.8777, "0.9": 0.8773}
}]]
local coeff = json.decode(jsoncoeff)
log.debug("CO EFF TABLE IS HERE")
log.debug(coeff)
log.debug(dump(coeff))
--    name = "Sinopé Manufacturer specific"
--    ep_attribute = "sinope_manufacturer_specific"
--    attributes = {
--       0x0003: ("firmware_number", t.uint16_t, True),
--        0x0004: ("firmware_version", t.CharacterString, True),
 --       0x0200: ("unknown_attr_1", t.bitmap32, True),
 --       0xFFFD: ("cluster_revision", t.uint16_t, True),
--    }

 --   signature = {
 --       # <SimpleDescriptor endpoint=1 profile=260 device_type=0
--        # device_version=0 input_clusters=[0, 1, 3, 12, 32, 1026, 2821, 65281]
--        # output_clusters=[25]>
 --       MODELS_INFO: [
 --           (SINOPE, "LM4110-ZB"),
 --       ],
 --       ENDPOINTS: {
 --           1: {
 --               PROFILE_ID: zha_p.PROFILE_ID,
--        --        DEVICE_TYPE: zha_p.DeviceType.ON_OFF_SWITCH,
       --         INPUT_CLUSTERS: [
      --              Basic.cluster_id,
     --               PowerConfiguration.cluster_id,
    --                Identify.cluster_id,
   --                 AnalogInput.cluster_id,
  --                  PollControl.cluster_id,
 --                   TemperatureMeasurement.cluster_id,
--                    Diagnostic.cluster_id,
--                    SINOPE_MANUFACTURER_CLUSTER_ID,
--                ],
--                OUTPUT_CLUSTERS: [
--                    Ota.cluster_id,


--Sensors LM4110-ZB, tank level monitor
--Cluster	Attributes	Atribute decimal	Data type	Fonction	Value	Access
--0x0001	0x0020	32	t.uint8_t	battery voltage	54, volt*10	report/read
--0x0001	0x0021	33	t.uint8_t	remaining battey percentage	%	report/read
--0x0001	0x003e	62	t.bitmap32	battery_alarm_state	0=ok, 1=weak battery	report/read
----	---	---	---	---	---	---
--0x0402	0x0000	0	t.int16s	MeasuredValue, device Temperature	celsius * 100	report/read
---	---	---	---	---	---	---
--0x000c	0x0055	85	t.uint16_t	Present value, angle	angle of the gauge needle in degree	report/read
---	---	---	---	---	---	---
--0xff01	0x0003	3	t.uint16_t	firmware_number		read
--0xff01	0x0004	4	t.CharacterString	firmware_version		read
--0xff01	0x0030	48	t.uint8_t	Unknown	60	report/read/write
--0xff01	0x0080	128	t.uint32_t	Unknown	0	report/read
--0xff01	0x0200	512	t.bitmap32	status	0x00000000	report/read
--0xff01	0xfffd	65533	t.uint16_t	cluster_revision		report/read

--Propane level is reported as gauge needle angle cluster 0x000c, attribute 0x0055. There is no % value. In neviweb this is calculated depending on gauge type 5-95 or 10-80. If you need to set an alarm at 20% tank capacity then target angle 182 for 5-95 and 10-80 gauge. For 30% value 5-95 = 221 and 10-80 = 216.



function common.value_handler(driver, device, value, zb_rx)

--   R3D-LP 5-95
--  
-- value.value  = value.value - 114 + value.value * 3.4


--   R3D-LP 10-80

local highpct = 70
local highdeg = 340
local lowpct = 20
local lowdeg = 182


local x = (device.preferences.highpct-device.preferences.lowpct)/(device.preferences.highdeg-device.preferences.lowdeg)
local y = device.preferences.lowdeg - device.preferences.lowpct / x
log.trace("x:" , x , "y:", y)
local  v  = (value.value - y ) * x  
log.trace("Converted Propane Value: ", v )
log.trace(string.format("Angle Raw Value: %.3f", value.value))
	v = math.max(v,0)
--	device:emit_event(capabilities['digitclever52707.propaneLevel'].propaneAngle({value = value.value}))
local lastvalue = 10.1 
local rate = 10.1

local lastvalue = device:get_latest_state("main",'digitclever52707.propaneLevel','propaneLevel',0)
local lasttime = device:get_latest_state("main",'digitclever52707.propaneLevel','propaneLastread',0)
local currtemp = device:get_latest_state("main",'temperatureMeasurement','temperature',nil)


if (currtemp == nil ) then 
	currtemp=oldtemp or 15
	log.error("Temp NOT read, using old:" ..  oldtemp)
else
	oldtemp = currtemp
end



local tempkey = string.format("%d", math.floor(math.abs(currtemp)))
local tempdec = string.format("%.1f" ,math.abs(currtemp) % 1)
if tempdec == "1.0" then 
	tempdec = "0.0"
	tempkey = string.format("%d", tempkey + 1)
end

if (currtemp < 0) then  tempkey = "M" .. tempkey end 

log.trace("Eff:" ,currtemp, tempkey .. " / " ..  tempdec)
local effrow =  coeff[tempkey] or  {}
if coeff[tempkey] == nil then log.error("Coeff not found") end
log.trace("EffRow", effrow)
log.trace("EffRow", dump(effrow))
local eff = effrow[tempdec] or 1
if  effrow[tempdec] == nil then log.error("Coefficient decimal not found") end
log.trace("Eff:", eff .. " " ..  tempkey .." / " .. tempdec)


log.info(lasttime, "/" , lastvalue)
local ts =  device.preferences.tankSize

local rate = ts * ( lastvalue - v ) * (os.time() - lasttime) / 3600
log.info ("Rate: ", rate)
if rate < 0 then
device:emit_event(capabilities['digitclever52707.propaneLevel'].propaneFillDate({value = os.date("%x %X", os.time())}))
rate = 0
end

log.info("Calculating: ",lastvalue ,"@" , lasttime, "=" , rate) 
log.info("Volume: ", lastvalue -v, "  Time", 3600 / (os.time() - lasttime))
device:emit_event(capabilities['digitclever52707.propaneLevel'].propaneLevel({value = math.floor((v*100+0.5))/100}),{ visibility = { displayed = true } })
device:emit_event(capabilities.vehicleFuelLevel.fuelLevel({value = math.floor(v+0.5)}))
device:emit_event(capabilities['digitclever52707.propaneLevel'].propaneRate({value = math.floor((rate*100+0.5))/100}))
device:emit_event(capabilities['digitclever52707.propaneLevel'].propaneLastread({value = os.time()}))
device:emit_event(capabilities['digitclever52707.propaneLevel'].propaneAngle({value = math.floor((value.value*100+0.5))/100}))
device:emit_event(capabilities['digitclever52707.propaneLevel'].propaneVolume({value = math.floor((v / 100 * ts * eff*100+0.5))/100}))


 local cosock = require "cosock"

    local http = cosock.asyncify "socket.http"
    -- ltn12 is a module provided by luasocket for interacting with
    -- data streams, we need to use a "source" to populate a request
    -- body and a "sink" to extract a response body
    local ltn12 = require "ltn12"

    local ip = device.preferences.webhookip  -- found previously via discovery
    local port = 1880 -- found previously via discovery

    local url = string.format("http://%s:%s/tank", ip, port)
    local body

    log.debug("Sending JSON TO : " , url)
    local j = {}
    j.tankLevel = v
    j.tankRate = rate
    j.tankAngle = value.value
    j.tankVolume = v / 100 * ts * eff
    j.currtemp = currtemp
    j.eff = eff
    j.tanksize = ts
 
    local msg = json.encode(j)
    for i=1,3 do
      local body_t = {}
      -- performs a POST because body parameter is passed
      local success, code, headers, status = http.request({
        url = url,
	method = 'POST',
        -- the `string` source will fill in our request body
        source = ltn12.source.string(msg),
        headers = {
        ["content-length"] = tostring(#msg),
	["Content-Type"] = "application/json"
    	},
    -- The `table` sink will add a string to a list table
        -- for every chunk of the request body
        sink = ltn12.sink.table(body_t),
        -- The create function allows for overriding default socket
        -- used for request. Here we are setting a timeout to 5 seconds
        create = function()
          local sock = cosock.socket.tcp()
          sock:settimeout(5)
          return sock
        end,
      })

      if not success and code ~= "timeout" then
        local err = code -- in error case second param is error message

        error(string.format("error while setting switch status for %s: %s",
                            device.name,
                            err))
       elseif code ~= 200 then
         error(string.format("unexpected HTTP error response from %s: %s",
                             device.name,
                             status))
      elseif code == 200 then
        body = table.concat(body_t)
	log.debug("Posted")
        break
      end

      -- loop if timeout
    end
end


function common.get_cluster_configurations(manufacturer,device)
    return {

	['digitclever52707.propaneLevel'] = {
		{
		cluster = zcl_clusters.AnalogInput.ID,
                attribute = zcl_clusters.AnalogInput.attributes.PresentValue.ID,
                minimum_interval = 5,
                 maximum_interval = 3757,
                  reportable_change = data_types.SinglePrecisionFloat( 0 ,-2 ,0  ),
		   data_type = data_types.SinglePrecisionFloat 		  
		}
	},
	['battery'] ={
--		{
--		 cluster = zcl_clusters.PowerConfiguration.ID,
--                attribute = zcl_clusters.PowerConfiguration.attributes.BatteryVoltage.ID,
--                minimum_interval = 60,
--                 maximum_interval = 43646,
--                  reportable_change = data_types.Uint8(1),
--                 data_type = data_types.Uint8
--		},
		{
		 cluster = zcl_clusters.PowerConfiguration.ID,
                attribute = zcl_clusters.PowerConfiguration.attributes.BatteryPercentageRemaining.ID,
                minimum_interval = 5,
                 maximum_interval = 65535,
                  reportable_change = data_types.Uint8(1),
                 data_type = data_types.Uint8
	
	}

    },
    ['temperatureMeasurement'] = {{
                 cluster = zcl_clusters.TemperatureMeasurement.ID,
                attribute = zcl_clusters.TemperatureMeasurement.attributes.MeasuredValue.ID,
                minimum_interval = 60,
                 maximum_interval = device.preferences.tempMaxInterval or 3600,
                  reportable_change = data_types.Int16(1),
                 data_type = data_types.Int16
                }

        }

    }

end



--Tank monitor LM4110-ZB:
--Data	Cluster	Attribute	format	min time	max time	minimum change	Note
--status		0x0001	0x003e	0x1b	60	43688	1
--remaining battey %	0x0001	0x0021	0x20	0	65535	1
--battery voltage	0x0001	0x0020	0x20	60	43646	1
--present value, angle	0x000c	0x0055	0x39	5	3757	1
--device temperature	0x0402	0x0000	0x29	60	3678	1	(only if temperature goes below 5oC)

return common

