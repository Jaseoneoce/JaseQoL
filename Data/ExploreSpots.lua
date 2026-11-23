-------------------------------------------------------------------------------
--  JaseTools: where to stand to explore each place of the "Explore <zone>"
--  Legacy Challenges (Modules\ExploreWaypoints.lua).
--    JQ.ExploreSpots[challengeID] = { map = uiMapID, { "areaID,areaID", x, y, outline }, ... }
--      x, y: where to go, on the zone's map (0..1)
--      outline: the ground that explores it; loops split by spaces, each point
--      four base-64 characters (n / 4095 * 1.25 - 0.125 across, then down)
--  Generated from OpenMap's Data\Forever\Explore.lua (OpenMap contributors, MIT,
--  https://github.com/openmap-world/openmap); regenerate rather than edit.
-------------------------------------------------------------------------------
local _, JQ = ...

JQ.ExploreSpots = {
    [627] = { map = 1426,   -- Explore Dun Morogh
        { "803", 0.6400, 0.4994, "mTdol9dol9gOlQgvlQiTm/iTnrhRpEhRpEfMoYfMoYeJ" },   -- Amberstill Ranch
        { "137", 0.2948, 0.4689, "VUbjUSdGUSfMUofMU+gvYygOZIeqWteJWBdGWBcE" },   -- Brewnall Village
        { "801", 0.3693, 0.5298, "Z1dGZIdoYygOXwgOXwiTXZi0YGj3Z1jWahiTa3gOb6ftb6eJa3eJahdG" },   -- Chill Breeze Valley
        { "800", 0.3558, 0.6618, "YGl8Xwl8XZqnWXrIWXsLXZsLXZssYcssYcplZeplZemd" },   -- Coldridge Pass
        { "132,77", 0.2542, 0.7430, "XZm+XDngPyngQIoBQIpDPypDQIw2Xww2YGssWXsLWXrIXZqn" },   -- Coldridge Valley
        { "135", 0.2610, 0.5298, "S5eJSjeJSjkYT8kYUSlbVUl8U+gOUogOUSeJ" },   -- Frostmane Hold
        { "809", 0.5250, 0.3775, "gwXZgaXZgabBifbBifXZ" },   -- Gates of Ironforge
        { "133", 0.2542, 0.4080, "WBWWU+X6TPX6S5ZeR3ZeR3doUSeJUocEVqbjVqZ/WBZ/WBYbWXYbWXWW" },   -- Gnomeregan
        { "134", 0.6874, 0.5806, "pEhyoCjWoCmdqdmdqdlbrJlbrJi0qdhy" },   -- Gol'Bolar Quarry
        { "212,716", 0.7686, 0.5704, "r2gOrfgOrfjWsMj3sMm+singu9ngu9mdvpl8wAkYxYkYxYjWvTjWvThyunhRungO" },   -- Helm's Bed Lake
        { "211", 0.3558, 0.3978, "YcXZXZX6XZY8VqZ/WBdGWteJXZeJXZeqZIeqZIdoaLdGahaga3agaLZeaLXZ" },   -- Iceflow Lake
        { "131,189", 0.4708, 0.5095, "eVdodoeqdShydohyd/jWfXjWfXgvgwgvgwfMfBeJfBdo" },   -- Kharanos
        { "138", 0.5791, 0.4385, "kOagifbjifdojheJjheqlQeqlmbjk6bjk6ag" },   -- Misty Pine Refuge
        { "808", 0.8228, 0.3471, "t7VUtkVUtkbBwAbBxCdGybdGyxclyxZeybZeyFVU" },   -- North Gate Outpost
        { "802", 0.4031, 0.4385, "bjXZaLX6ahZ/cmZecmX6 a3agahagaLdGa3eJcQeJcQclbjclbjbj" },   -- Shimmer Ridge
        { "806", 0.8566, 0.4994, "xYdowseJxChyxYhyxYi0yxi0yxhyzzgvzzdo" },   -- South Gate Outpost
        { "136", 0.4234, 0.5603, "bjgOahhRaLi0ahi0ahj3bjlbc8l8dSk5d/k5d/i0doi0dShRcmhRcmgO" },   -- The Grizzled Den
        { "804", 0.5723, 0.5907, "i1gvhzhRgwi0gwl8iJl8i1oBl9ngl9m+oCmdoCiTnViTnVi0k6i0kkhyjhhyjhgv" },   -- The Tundrid Hills
    },
    [728] = { map = 1411,   -- Explore Durotar
        { "370,410", 0.5272, 0.2246, "glPugQPugQRqf8RLfSRqfnUkhOVDhOUFglTmg6THhjUFhjVDiMViihVDihRLh4QN eUVDeAVDeAX8eUYbf8YbglXdglWgfSWge+VD" },   -- Drygulch Ravine
        { "368", 0.6470, 0.8771, "opncoVncoVpYoAp3mEp3mEq1lbq1lbsxkdtvkIwJjfwJjKxmiMyFh41eih1eih2ckI43kx43lv6UnX6Unr7Sp87Sp86Uq643q651rj6zsh6zsh4YsM4Ysh2csM2csM0/rj0grjwJsMwJsMvqs2vqtfust0rUtKrUs2p3r4oaq6oaq6nc" },   -- Echo Isles
        { "366", 0.4894, 0.7920, "eUtQdrtvdrwJglwogluOf8tQ" },   -- Kolkar Crag
        { "1637", 0.4515, 0.0449, "aIFEY1GhY1HfZfH+ZfI8axK4baK4bvMVfnMVf8I8glH+hOH+h4GhihGhi2FjjfFjjfFE" },   -- Orgrimmar
        { "362", 0.5398, 0.4232, "iMaXh4a2gQa2f8bVf8dRi2dRjKcyjKaX" },   -- Razor Hill
        { "816", 0.4452, 0.4799, "bvY6axZ4bGcTeAbVdrZZ ctcTcYcybGcybaePbvePcEhJglgqgldwe+dwe+dReAdRdrcT" },   -- Razormane Grounds
        { "367", 0.5587, 0.7447, "ihrUh4rzh4tviMtviMusjKusjztvjzsxkIsxkIrU" },   -- Sen'jin Village
        { "817", 0.5398, 0.1017, "hjJ6hOJ6hOM0hjNTjKNTi2J6" },   -- Skull Rock
        { "369", 0.4011, 0.2624, "adRqZfSoZzXdbGXdbvWgbvVDcYVDdWTmdCRq" },   -- Thunder Ridge
        { "372", 0.5776, 0.5650, "jfgLi2gqi2iHihiHihlBjflgjzmelbmelbimkxhokxgL" },   -- Tiragarde Keep
        { "363", 0.4389, 0.6407, "cYhobaiHaxjFaxlBaIlBaIo5ado5bGrzdCsSdCsxeUsxepq1fnq1gQp3gQoafnn7fnkDe+jkepiH" },   -- Valley of Trials
    },
    [736] = { map = 1412,   -- Explore Mulgore
        { "404", 0.3460, 0.5322, "YigMXbgnW3hcW3jGYQjGYQjhZFjGZFgM" },   -- Bael'dun Digsite
        { "222", 0.4705, 0.6216, "eWkWc9mBc9m2dhm2eWoGeWo7eoo7fvnRfvmb" },   -- Bloodhoof Village
        { "818", 0.3622, 0.6541, "YimbX+m2X+ogYQo7Zoo7Z6nRZXmb" },   -- Palemane Rock
        { "224", 0.5193, 0.5241, "g2gMgSgngSh2h9ish9hBhZgM" },   -- Ravaged Caravan
        { "220", 0.4651, 0.8654, "dhr1cIsrbTt6bTvKaMvlaMwaZow1ZoyFaMyfav0kbl10cI10cI2pjE2pkd0kkdzvlAzvkuyFjnyFiyw1iPtFgktFgSr1fLr1e6sr catFdhtFdhuwcauw gkuwhZuwhZwAgkwA" },   -- Red Cloud Mesa
        { "225", 0.5789, 0.3128, "kdUIkLUjigUjigXdiyXdiyaXjEaykLaykuZ9kuZHlSYtlSVYlAVYlAUI" },   -- Red Rocks
        { "820", 0.4976, 0.4104, "gSTTeWVyeWX4eEYSc9YSc9ZHcaZ9cscccIcccIc3c9dSc9ehdhfXhZgMhZfxiPfxiye8iydSjEdSjEaXiyaXiyXdigXdigTT" },   -- The Golden Plains
        { "821", 0.5951, 0.7110, "nxnRngnRngpWmqpWmqnrmZoGlSoGlSogjEoGjEo7iyo7iysrkLsrkLtFmqsrmqtFnxtF" },   -- The Rolling Plains
        { "360", 0.5789, 0.5322, "jWgnjEgnjEisj5j8kdj8kugn" },   -- The Venture Co. Mine
        { "1638", 0.4001, 0.3535, "aMVYZ6VYZoXdYzXdYzayZFbNbBbNbTaXcaaycaZ9c9ZHc9X4caXdcaVy" },   -- Thunder Bluff
        { "397", 0.4435, 0.5079, "dPehcIfxcIhBcsh2dhh2eEhBeEfXdhfX" },   -- Thunderhorn Water Well
        { "398", 0.4272, 0.2478, "cIRobTSdbTTtb2UjcsUjdPTtdPSdcsRo" },   -- Wildmane Water Well
        { "819", 0.5085, 0.2072, "fdOufLOufLPjdhPjdhRoe6RogBTTigTTiPQzg2Ou" },   -- Windfury Ridge
        { "396", 0.5193, 0.6866, "g2oGgBo7gBqLgkrAhZrAh9qLh9o7hZoG" },   -- Winterhoof Water Well
    },
    [750] = { map = 1413,   -- Explore The Barrens
        { "1700", 0.4184, 0.4878, "aZb9aOb9Z4d/ZjePZjfwaOgAaZgwa5hhbOhhcljydwjid7jCexiyexiRe7iRe7ggcvdOcadObvb9" },   -- Agama'gor
        { "359", 0.4842, 0.8480, "e7wreQw7eGx8dwycdaycdQy8exy8exzMfGzMfGztf8ztf8ysgcyMgcxLf8w7f8wr" },   -- Bael Modan
        { "1701", 0.4250, 0.8036, "bktIa5tZaZuJaZwKajwKajwrbExbcExbcPx8cvx8cv0NdF0NdFycd7xbd7vKdwvKdwupdFtpcPtpcEtI" },   -- Blackthorn Ridge
        { "381", 0.6157, 0.0438, "lrGwlgGwlgHQlKHwlKJRlgJRlgJyl1KSmWKSmgKCmgGw" },   -- Boulder Lode Mine
        { "1698", 0.5204, 0.5470, "gngQgcgQgcgwgHgwfxhRfxjigckjgykjhIlThzlTh9kzizkji+kTi+jCiTiRiThRhogQ" },   -- Bramblescar
        { "378", 0.4546, 0.5914, "dQjicvkDc6lkeQlkeQjy" },   -- Camp Taurajo
        { "384", 0.4809, 0.1918, "eGO1d7O1d7PldlPldlQWemQmemRXfxRGfcPV" },   -- Dreadmist Peak
        { "379", 0.6190, 0.2017, "mLQGl1QWmARGmWRGmWQG" },   -- Far Watch Post
        { "390", 0.4776, 0.7098, "bko2bOpGbOrXb6sYd7sYd7pmdapmdFo2 fnpGfGpWfGpmeGpmeGsYfnsYfnrXgHq3gHpmf8pmf8pG" },   -- Field of Giants
        { "1704", 0.5565, 0.2017, "h9P2hSQmhdR3ieR3ieRnjpRnj0RXj0QGjpP2" },   -- Grol'dom Farm
        { "1702", 0.3822, 0.2855, "ZNR3ZCR3ZCXrZtXrZtXKaDXKaZWaauWabEV5bESnajR3" },   -- Honor's Stand
        { "387", 0.4677, 0.3941, "dlY7daY7dQatdaatdabNeGcOemcOexbtfcbdfRZse7ZM" },   -- Lushwater Oasis
        { "385", 0.6125, 0.5470, "j0gAjegQjegwj/hBkKhhkfhhkfjCkKjSkfkDmWkDmgkznWkjnhiinMiRnMhBm2hBmgggk1ggk1gQ" },   -- Northwatch Hold
        { "1697", 0.5763, 0.5470, "jegwjUgwjJiyjejSkUjSkfjCkfhhkKhhj/hB" },   -- Raptor Grounds
        { "392", 0.6256, 0.3793, "mWYLmAYbmAY7k/ZMk/bNlgbNlga9nMa9nMZMmrYrmrYL" },   -- Ratchet
        { "1316", 0.4973, 0.9319, "day8dQy8dQ0tdl0tdl1eeG2Oex2Oex3PfG3vfc3vf84wg95AhS5gi+5gi+4Qiz4Qiz3fip3fie2vhd2egS0Nfn0NfcztfGztfGzMexzMexy8" },   -- Razorfen Downs
        { "1717", 0.4250, 0.8973, "cEz9bk0Nb60+cv0+dF0dcvz9" },   -- Razorfen Kraul
        { "380", 0.5204, 0.3003, "gcU5gSU5gcWKgyWagyW6hSW6hdV5hoV5hoVJhdU5" },   -- The Crossroads
        { "383", 0.3921, 0.1523, "Z4KyY4MTY4NkYiN0YiPFZNQGZjQGaDRGb6Q2cPQWcPMjbkMjbkLza5Ky" },   -- The Dry Hills
        { "386", 0.4480, 0.2411, "dQQWc6Q2clQ2clRXdFRndFR3cvSHcvSncaSncaTYdQT4dQUIdlUIdlToeQS4eQSXd7SHd7RX" },   -- The Forgotten Pools
        { "391", 0.6486, 0.4878, "nWX7nBYbmrYbnMZMnMa9mWa9mWcOmgcOmgc+mrc+mrdemgdemrevmLfQmAggmgggmggwnMhBnMiRnhiinhkDnskDn3jioMjioijCpCjCpCiiqNiiqjiBquggq5ggrDdeq5dequcuqYcuptbtptZ8pNZ8pCZMoiZMoXYLn3YbnsX7 nsb9oBb9oXceoXdOnhdenhcO pYd/qYePqYevqjevqYgQpCggotgAote/" },   -- The Merchant Coast
        { "1703", 0.4875, 0.0586, "emIhd7JRd7KCfGKCfGKSgcKCgcIh" },   -- The Mor'shan Rampart
        { "382", 0.5664, 0.0833, "i+JyizJyizLTi+LjjeLjjeLTj0LTkKKykKKSj0Jy" },   -- The Sludge Fen
        { "388", 0.5532, 0.4237, "izach9a9hzcOhdcOhzePiIePiedejUdOjUcujecujpbNjJac" },   -- The Stagnant Oasis
        { "1699", 0.5796, 0.2609, "ieSHhdSnhdUIh9U5jeU5kKV5kKWamAWamAVpl1Vpl1U5lrU5lgT4k/Tok/SX" },   -- Thorn Hill
    },
    [760] = { map = 1416,   -- Explore Alterac Mountains
        { "1684,3486", 0.7857, 0.5982, "x+VCxXVCxXXxu7Xxu7bbttbbr4eLr4oOsfpJwwqDx+oOx+lfxXlfx+gAwJdQwJZmwwYsylZmylV8 wwr4u7szu7uox+ySzMwdzMttx+tt" },   -- Chillwind Point
        { "1679", 0.4643, 0.7768, "eeoObbszbbuocpwdcpzMeezMee1BgT1Bg60HgTqD" },   -- Corrahn's Dagger
        { "282,283", 0.4881, 0.4018, "fFUHeeVCa0VCaNXxcpYsdQcWgTgAgTfFiveLivahhhYsgTYs" },   -- Crushridge Hold
        { "279", 0.1786, 0.7054, "LlgAK+gAKXqDLlq+MzxXRrzMRr0HTg0HTgxXVVwdVVttWjttWjr4V8q+Tgq+S5mZQdivPPivPPgA" },   -- Dalaran
        { "1682", 0.4048, 0.1696, "ZmKEXxL5Y/NuY/RYYYSSaNVCcCVCcCSSd3RYd3KE" },   -- Dandred's Fold
        { "1357", 0.4881, 0.5804, "iIeLfFgAeeh1dQh1cCjqcClfd3oOfsoOiIjqlLh1lLg6ivg6" },   -- Gallows' Corner
        { "1677", 0.3214, 0.8125, "XKr4Wjr4WjttVVttUu0HXK0HZmwdZmttXxtt" },   -- Gavin's Naze
        { "1683", 0.3929, 0.6875, "bblfa0mZYYmZYYpJXKpJXKszXxttbbttd3qDd3nUcplf" },   -- Growless Cave
        { "278", 0.1548, 0.9018, "MzwdK+xXK+zMMMzMNa3xP23xRr1BRrzMOByS" },   -- Lordamere Internment Camp
        { "1681", 0.2976, 0.4018, "WjXxS5dQREeLTgh1UHh1UHfFV8eLV8cWYYYsYYXx" },   -- Misty Shore
        { "281", 0.3810, 0.4911, "ZmV8YYW3YYYsXKZmV8eLUHfFUHmZV8pJYYpJYYmZcClfcCjqfsgAdQcWdQZma0YsaNV8" },   -- Ruins of Alterac
        { "1678", 0.5833, 0.6875, "ivjqhhkkhhoOivpJjWr4lLr4lyq+lynUkklfjWlf" },   -- Sofera's Naze
        { "280", 0.5952, 0.4375, "jWZmivZmiveLiIeLivg6lyg6mZfFnnfFnnZm" },   -- Strahnbrad
        { "1680", 0.3929, 0.8661, "aNttZmttZmwdYYxXYY1BY/1BZm3xbb3xcpwdcCwdbbtt" },   -- The Headland
        { "284", 0.5595, 0.2946, "WjIPV8IPV8L5WjMzXxMzY/KEa0KEa0JJY/JJY/IP eeK+d3K+d3RYcCSScCVCeeVCfFUHgTYshhYsiIahivZmnnZmnnXxlyV8lLRYjWOojWL5hhMzgTK+ Y/SSV8V8V8XxYYXxY/V8a0V8" },   -- The Uplands
    },
    [761] = { map = 1417,   -- Explore Arathi Highlands
        { "1858", 0.3472, 0.4375, "XeY5VkbBVkfSWhgtZXgtayelayaUZXZmZXY5" },   -- Boulder'gor
        { "316", 0.5324, 0.7708, "g8rYgAsFgAwWjywWkRvpkRsF" },   -- Boulderfist Hall
        { "333", 0.6713, 0.2847, "nHSfmoSfmoWDnlWwnlYLq5YLq5Sf" },   -- Circle of East Binding
        { "335", 0.3472, 0.5903, "WhhbWDhbWDn0aUn0aynHayjjZ1iI" },   -- Circle of Inner Binding
        { "336", 0.5231, 0.4931, "ged3fhelfhiIiXhbiXd3" },   -- Circle of Outer Binding
        { "334", 0.2546, 0.2986, "TNTNSQT6RyWwSuYLUJYLVGWwVGT6" },   -- Circle of West Binding
        { "315", 0.5509, 0.3958, "g8VVgeVVgeccg8ccg8d3jyd3kvcckvVV" },   -- Dabyrie's Farmstead
        { "327", 0.2917, 0.8264, "VktgVGuOQ1uOQ1xESuwWTrxxUJ0nWD0nWDzMW/xxZXxxZXuOY5tg" },   -- Faldir's Cove
        { "314", 0.6065, 0.5625, "kvgAjUhbjUmZkRn0nHn0oDmZoDiInliInHgA" },   -- Go'Shek Farm
        { "321,318", 0.7639, 0.3681, "rYSfq5Sfq5dKxidKxiWwusWDusT6tvSf" },   -- Hammerfall
        { "313", 0.3287, 0.2847, "X8PpWhQXVGSfVGWwWDYLY5YLZXXeZXPp" },   -- Northfold Manor
        { "320", 0.4583, 0.4653, "dKbvbvdKbvhbcNiIfhhbfhelg8d3g8ccgebv" },   -- Refuge Pointe
        { "324", 0.2361, 0.6181, "Ryi2N/oiN/p9O8rYRyrYSupPWDpPWDi2" },   -- Stromgarde Keep
        { "880", 0.4491, 0.8958, "cNzMbvzMbv2Cel2CeGzM" },   -- Thandol Span
        { "1857", 0.1806, 0.3542, "VkMzRTTNRTUoPaWwOdbBNhbvNhelOdd3OdccO8ccPaZmQXY5QXXeUoREUoPpWDNh" },   -- Thoradin's Wall
        { "317", 0.6898, 0.7014, "oijjoDjjoDmZnHn0kRn0i2p9i2sFkRsFkRuOlsuOnHwWr2wWsUvpsUsztvsztvjj" },   -- Witherbark Village
    },
    [765] = { map = 1418,   -- Explore Badlands
        { "345", 0.4975, 0.7198, "fhlmdenpdev4g5v4g5u2i9t0i9org5lm" },   -- Agmond's End
        { "338", 0.4305, 0.3379, "auTEaCTEaCbTaucVdecVeKZPfhYOfhWKdeTE" },   -- Angor Fortress
        { "337", 0.1625, 0.6193, "MUheLoheLonpMUorRHorRHig" },   -- Apocryphan's Rest
        { "342", 0.6181, 0.6997, "mYlmjporjpt0oct0oclm" },   -- Camp Boff
        { "344,347", 0.1223, 0.8204, "I5rxINrxINz/I51BMU1BMU2DPE3FPw2DPwrx" },   -- Camp Cagg
        { "341", 0.6583, 0.2173, "lsP/lBP/lBUGqgUGp0P/" },   -- Camp Kosh
        { "1898", 0.6449, 0.3379, "lsUGlBUGlBaRkVaRlBeZpIeZpIaRtPZPtPUG" },   -- Dustwind Gulch
        { "346", 0.5377, 0.3379, "gNUGfhUGfhZPgNaRjpaRjpUG" },   -- Hammertoe's Digsite
        { "340", 0.0687, 0.4384, "INaRG1bTG1heKQheKQfaLofaLoaR" },   -- Kargath
        { "339", 0.8057, 0.5389, "tPTEsjTEtPUGtPZPr4ZPr4cVp0faocfap0szwrrxwrqvyDqv1elm1eeZ2KeZ1eTE" },   -- Lethlor Ravine
        { "1879", 0.3233, 0.7198, "T3lmSfmnTLx8auw6auu2deu2cylm" },   -- Mirage Flats
        { "1878", 0.2295, 0.4384, "RHYONscVNseZNAeZNsigRHigRHmnTLmnT3lmT3gcXTgcXTlmaulmaubTaCbTaCYO" },   -- The Dustbowl
        { "1897,1517", 0.4573, 0.1369, "cGJ0baJ0baP/cySCfhSCfhP/hlN7hlJ0" },   -- The Maker's Terrace
        { "1877", 0.4439, 0.5389, "cydXaueZaulme1lmg5igg5fafhdX" },   -- Valley of Fangs
    },
    [766] = { map = 1419,   -- Explore Blasted Lands
        { "1441", 0.3905, 0.3209, "ZoUKYnU7YnYvbqYvbqUK" },   -- Altar of Storms
        { "1437", 0.4502, 0.1567, "bKKOapKOapUKdMUKdtR3fvR3fvQVgwOzgwK/fvLwfvK/dtK/dtKO" },   -- Dreadmaul Hold
        { "1439", 0.4801, 0.4254, "fPZgdtbCeNeFgQdUgQZg" },   -- Dreadmaul Post
        { "1457", 0.5796, 0.1418, "j0MhjTMhjTOzk1Ozk1Mh" },   -- Garrison Armory
        { "1438", 0.6393, 0.1866, "izMhhyNSiSTZlWSolWTZm4TZm4UKpbUKqcSoq8OCp7Mhk1Mhk1OzjTOzjTMh" },   -- Nethergarde Keep
        { "2517", 0.4900, 0.3060, "eNR3dMTZdMX+hRYvhRUKgQUKfvR3" },   -- Rise of the Defiler
        { "1440", 0.6393, 0.3209, "l2TZlWTZlWX+m4aRo6aRo6UK" },   -- Serpent's Coil
        { "72", 0.6095, 0.5448, "kVdUizfnfPhJfvmfgwmfhyoBl2oBm4mfo6mfo6dU" },   -- The Dark Portal
        { "73", 0.3806, 0.6791, "VjbzUicjUihJUBhJUBx9cLxMcL4Ecs3Teu3TfP2ifPxMfvxMfvnQfPnQfPk9dMh6bqhJbqe2ape2ZodUZobz" },   -- The Tainted Scar
    },
    [768] = { map = 1420,   -- Explore Tirisfal Glades
        { "157", 0.4758, 0.3389, "hNS8g1TgcTTgbLVNbjYme8dsg1dIhNYCjGWVjGUoh+S8" },   -- Agamand Mills
        { "165", 0.7709, 0.6155, "s6jXsKj7sKnUtTpBuDn5wUn5wUmwwsmwwUj7" },   -- Balnir Farmstead
        { "162", 0.6823, 0.4827, "qRYmoxZKoYa3nQcknQfZoAfZphiOrCiOqpe1rydIraZu pha3qpa3qRdIoxdIoxbbphbb" },   -- Brightwater Lake
        { "159", 0.6012, 0.5048, "jGeQiueQiughj2ghkniOmgiOmgfZmHe1" },   -- Brill
        { "166", 0.5348, 0.5823, "hNiOgdiygdlDg1loiulojGlDjGiy" },   -- Cold Hearth Manor
        { "167", 0.7930, 0.5491, "s6hGsihGsijXwUj7wUhG" },   -- Crusader Outpost
        { "154", 0.3356, 0.6598, "TPiOS3iOS3s/Uws/UwtjWptjWpuHXZuHXxs/ays/aymwaamwayiyaaiO TPjXVIjXVImMTPmMTPkfTnkf" },   -- Deathknell
        { "164", 0.5791, 0.3499, "jeVxiWW5iWZujGa3lva3lvWVlXVx" },   -- Garren's Haunt
        { "811", 0.4463, 0.6598, "bLiyayiyaykfaakfaysbe8sbe8rSfUrSfUkfdcj7dDiy" },   -- Nightmare Vale
        { "459", 0.7782, 0.3389, "uzSXubSXubUEtTUotTWVs6WVtTa3uDa3uDaTuzaTvkZKv8SX" },   -- Scarlet Watch Post
        { "156", 0.3578, 0.5048, "Xxe1XZe1XZhqaahqaae1" },   -- Solliden Farmstead
        { "810", 0.4905, 0.5159, "gFdIfUdsfUe1eMe1eMfZdDf9dDiOdciygFj7hNiOhNdI" },   -- Stillwater Pond
        { "152", 0.8373, 0.6929, "xEmMwUmwwUuHx1uHx1mM" },   -- The Bulwark
        { "1497", 0.6188, 0.7163, "" },   -- Undercity
        { "812", 0.8741, 0.4827, "yNYmwUa3wUlDztlD2XhG2XZuztZuztYm" },   -- Venomweb Vale
        { "160,161", 0.8373, 0.3389, "wsUov8VNwUZKx1ZKyNYmyNW5xcW5x1Uo" },   -- Whispering Gardens
    },
    [769] = { map = 1421,   -- Explore Silverpine Forest
        { "233", 0.6190, 0.6369, "mSjDl4jqj2jqiolfiopJjcqXngq+oUpwoUoipIn7pIkRoUjD" },   -- Ambermill
        { "231", 0.6032, 0.7440, "kqqXkQqXkQuBnGuBmSq+kqq+" },   -- Beren's Peril
        { "213", 0.5635, 0.4702, "ioc9iOc9iOgAj2gAkQfZkQc9" },   -- Deep Elem Mine
        { "172,232", 0.6667, 0.2560, "rKOUn6Pin6QJnGQJl4R+l4TzmsVBnGYsn6Z6ouZ6ouahrkahrkZ6syZ6syYsuAYsuaXewCW2wCUavOTzvOR+uaRXuaPitMPitMOU qWR+sYR+tMTMtMVor+XeqWXep8W2" },   -- Fenris Isle
        { "238,239", 0.5238, 0.1369, "ioJciOJciOL4gmLRfyMffyO7h0PiiOO7iOL4ioMflEL4lEJc" },   -- Malden's Orchard
        { "928", 0.4127, 0.2917, "ZsQwZSQwZSTzZsTzaGWPa6W2a6YFdWYFdWUaciUabUSlbURX" },   -- North Tide's Hollow
        { "229", 0.4683, 0.5417, "ekgndWhOdWjqfYjqfYgn" },   -- Olsen's Farthing
        { "204", 0.4524, 0.7321, "ciqXcIqXcIszcitae+tafYszfYq+" },   -- Pyrewood Village
        { "236", 0.4444, 0.6726, "bUmta6mta6pwbUqXekqXekq+fYq+fYn7eKn7dWmt" },   -- Shadowfang Keep
        { "240", 0.4524, 0.2202, "dWPiciQJciTzeKTzekTMekPi" },   -- The Dead Field
        { "237", 0.5635, 0.3512, "ioVBiOVBiOZ6lEZ6lEYsj2W2j2VB" },   -- The Decrepit Ferry
        { "230", 0.4762, 0.8512, "buuoagvPaGwdY4wdY4ySa6ySbuzgek0Hfy18kq1VmS3xms6Nng5mng3xlE0HiO0HiOyShAySgMv2" },   -- The Greymane Wall
        { "228", 0.4444, 0.4107, "c8ZTciZTciahbuahbuc9dwdkeKc9eKZT" },   -- The Sepulcher
        { "927,227", 0.5397, 0.2560, "p8I1oULRnGLRmSMfj2NGioO7ioQJh0Qwh0R+hAR+gMVBgmVoj2VBjcQJleQJmsNtouNtpIL4rKL4qwJc" },   -- The Shining Strand
        { "226", 0.3651, 0.1607, "YEL4XQMfXQOUYEO7YEQwZsQwbUOUbUMf" },   -- The Skittering Dark
    },
    [770] = { map = 1422,   -- Explore Western Plaguelands
        { "2298", 0.6899, 0.7500, "pho7n7rTmvrTmvtsniuSniveoVwqqtwqsTuSsTr5rHqtrHph" },   -- Caer Darrow
        { "200", 0.4651, 0.5058, "c0dBboeNcChydOjkgZi+gZezfNdB" },   -- Dalson's Tears
        { "2297", 0.5891, 0.7384, "p6jkphjkphkwoVmjlKl8hlrThltGixu4jku4j9wEkwwEkwxQljycmWycmW0PpI0PpIzpsTzCtGx2vFxQwRvewRo7v3o7v3nvurnvuSlWtfkK pIo7qto7rHqtsTr5sTuSqtwqoVwqniveniuSmvtsmvrTn7rT" },   -- Darrowmere Lake
        { "199", 0.3721, 0.5407, "ZQezXqfZXqkwa1kwa1kKbokKcCjkboez" },   -- Felstone Field
        { "201", 0.6512, 0.5756, "pIgmmvhyljjkj9jkj9nvlKl8oVmjphkwphgm" },   -- Gahrron's Withering
        { "190", 0.4419, 0.1570, "a1J+acJ+acSTfNSTfmRtfmJ+" },   -- Hearthglen
        { "192", 0.4651, 0.3314, "boS5bPS5bPapbobPfmbPgAaDgyaDhlY2hlS5" },   -- Northridge Lumber Camp
        { "193", 0.4419, 0.6686, "dOkKc0kwbPkwacl8Y2l8Y2qHa1tGeatsezr5gZqtgZmjgAmjgAlWfNkK" },   -- Ruins of Andorhal
        { "197", 0.4806, 0.7965, "gZqtfNrTeatsdOtsdOxQeaxQeax2fNx2gAzCkXyckwwEixu4hltGhlr5gyr5 gZuShMuShMveh+wqh+ycgZyc" },   -- Sorrow Hill
        { "813", 0.3101, 0.5756, "XRfZWef/WehMVrhMU4iYU4oVXRoVXRnJXqnJXqfZ" },   -- The Bulwark
        { "198", 0.6589, 0.4244, "nJXqmvXqmWeznJf/phf/phapouZcnJZc" },   -- The Weeping Cave
        { "202", 0.5426, 0.6337, "gAjkfmjkfmlWgZmjgZrThlr5j9oVj9jk" },   -- The Writhing Haunt
        { "2620", 0.6512, 0.3547, "nJPVmWP7mWVSmvVSnJZcouZcphapphjkqUjkqUapniWeniPV" },   -- Thondroril River
    },
    [771] = { map = 1423,   -- Explore Eastern Plaguelands
        { "2624", 0.4479, 0.3983, "cvXhawZTbJdebjeEeueEfhc4fhYHfHXh" },   -- Blackwood Lake
        { "2264", 0.5332, 0.5843, "gTf2f6f2gTjbf6jbfhlzgTm/iSm/jelNjeiOh5f2" },   -- Corin's Crossing
        { "2263", 0.3550, 0.6424, "XMlNWZlzWZoLWyoxZkoxZklzZKlN" },   -- Crown Guard Tower
        { "2262", 0.3395, 0.7703, "Wyp+VmrKVms8Uzs8UzxHawxHaws8Yxp+" },   -- Darrowshire
        { "2271", 0.5952, 0.3866, "jFXhiSYHjFZTjFcRjec4l3c4mpbrmpYtl3Xh" },   -- Eastwall Tower
        { "2621", 0.5254, 0.7122, "f6m/fHnlfHs8fhs8fhuIf6uujeuujerKkRqkkRoxjFm/" },   -- Lake Mereldar
        { "2268", 0.7191, 0.5029, "racRpbeEpbi0p1jbsNjbsNiOtAiOtAc4" },   -- Light's Hope Chapel
        { "2272", 0.6494, 0.2471, "lEPLkrPLkrT8mQWUp1WUp1PL" },   -- Northdale
        { "2275", 0.4867, 0.1890, "fHN/d7PLd7Rkf6RkgTQ+gTN/" },   -- Northpass Tower
        { "2622", 0.6571, 0.5262, "n2eEmQf2mQknoPknpbi0pbeE" },   -- Pestilent Scar
        { "2277", 0.2697, 0.2936, "YYKbX+LBWZLBWZPLUaPLUaPxRPPLRPLBK5LnK5Q+NqQ+OdSKOdWUK5WUK5bFV/bFV/afWyafXlZTaXZTaXVIbJUibJQ+aXQYaXPLbJOlbJKb" },   -- Plaguewood
        { "2276", 0.4557, 0.1192, "cvKbcVKbcVOlcvOlcvPxd7PxeuN/f6N/f6Kb" },   -- Quel'Lithien Lodge
        { "2279", 0.2852, 0.1308, "RoLBRPLBRPPLTOPLTOPxWZPLWZLB" },   -- Stratholme
        { "2627", 0.1225, 0.2587, "LSQ+K5Q+K5WUOdWUOdSKNqQ+" },   -- Terrordale
        { "2258", 0.3472, 0.4331, "X+ZTV/afV/bFVNbFVNeqWZgcX+gcX+f2ZkfQZ9deaXdeaXafZkZT" },   -- The Fungal Vale
        { "2623", 0.4634, 0.5727, "dihCb8i0b8m/cvm/dilzfHlzf6knf6jbgTjbf6hC" },   -- The Infectis Scar
        { "2260", 0.2310, 0.6308, "RPknQDlzQDnlSCoxSCpXTnpXTnlzS0kn" },   -- The Marris Stead
        { "2270", 0.7501, 0.3634, "rBT8qOUiqOW7p1W7p1YtqnZTqnc4rBcRu/cRu/T8" },   -- The Noxious Glade
        { "2261", 0.2387, 0.7703, "RPp+Q1p+Q1whUzwhUzs8UAsWUArKTOp+" },   -- The Undercroft
        { "2619", 0.0528, 0.4215, "IHVIHuVIHucRKfgcKfpXLSpXLSeEKGc4KGW7JsW7JsVu" },   -- Thondroril River
        { "2266", 0.7424, 0.7122, "ralzqOmZqOm/pCm/pCoLpboLpbuIqOuIqOuuuMuuuls8u/s8ullz" },   -- Tyr's Hand
        { "2273", 0.6184, 0.0959, "jFHcisHcisPxooPLooHc" },   -- Zul'Mashar
    },
    [772] = { map = 1424,   -- Explore Hillsbrad Foothills
        { "288", 0.2760, 0.5859, "TvgzRmjMRmmZTMmZURqZWZqZXeozXej/V3iZV3gz" },   -- Azurelode Mine
        { "1056", 0.4844, 0.3359, "eZTNd3TNdVXMcRXMcRYzd3Zmd3aZgAaZhEYzhEXMhmXMhmUzgAUzgATN" },   -- Darrow Hill
        { "290", 0.6927, 0.7422, "qqnMpEn/m7rMm7szpEvMpmzMrMzMruvMsQvMsQrMrurM" },   -- Dun Garok
        { "275", 0.7969, 0.3984, "uZUAtVVmrMWZpmYzpmbMqIbMqqeZrueZtVgzv/iZ0ybM0yXMyqXMxEUA" },   -- Durnholde Keep
        { "294", 0.5990, 0.8672, "iIlmhmlmhEqZgArMgAtmeZuZe7yZhE0yhE7MtV7MtV4yru4yrM3Mpm2ZpEvMm7r/lVrMkzn/jMlm" },   -- Eastern Strand
        { "286", 0.3281, 0.3672, "XeQzWZRmWZUAUzUASqXMSqZmSIZmSIdmSqeZZEfMZEeZaIeZbMczbMaZbvaZcRXMbMWZaqSZZmUAXeUA" },   -- Hillsbrad Fields
        { "289", 0.6406, 0.6172, "kzgzkRgzjunMkzn/lVrMm7r/pEn/qqnMqqjMqIiZndiZm7gz" },   -- Nethander Stead
        { "896", 0.1823, 0.8203, "O7qZNVrMLNuZKqyZMR0yNV0yN32ZSq2ZTM1mTMyZURwyURuZRmqZ" },   -- Purgation Isle
        { "285", 0.2031, 0.5234, "QAeZO7fMO7jMPej/Rmj/TMhmTMfM" },   -- Southpoint Tower
        { "271", 0.4948, 0.5547, "d3fMdVfMdVmZeZmZfdozhEozhmlmiqlmiqgzhmfM" },   -- Southshore
        { "272", 0.6198, 0.2109, "kRMzjMNmjMUzjuVmoiVmpEUzpEPNndMz" },   -- Tarren Mill
        { "295", 0.4323, 0.7266, "RElmPemZPepmMRqZMRszNVrMOZrMOZqZRmqZURuZTvyZV3xmV3v/aIv/aIvMcRvMcRv/eZwyeZuZgAtmgArMhEqZhEozfdozeZmZdVmZcRn/Xen/WZqZURqZTvnM" },   -- Western Strand
    },
    [773] = { map = 1425,   -- Explore The Hinterlands
        { "348", 0.1061, 0.4740, "LnbAKSdAKSgVN1gVN1fqPKfqQCeVQCbA M8brORbrOReVM8eV" },   -- Aerie Peak
        { "1884", 0.4610, 0.4091, "cdZBcAZBcAeVgAdrgAaWfHZB" },   -- Agol'watha
        { "1885", 0.3225, 0.5909, "WQiUVziUVzmUWQm+YBm+YBi/" },   -- Hiri'watha
        { "354", 0.6255, 0.7468, "jGmUiNnphVnphVpoiNqTiqvnlUznn+znoayRpTyRqowSqosTqMsTpvnppTm+mNm+mNmU" },   -- Jintha'Alor
        { "1882", 0.2359, 0.2922, "RYTsQ7TsQ7VBR0VsR0dATldrTlVBStTs" },   -- Plaguemist Ravine
        { "350", 0.3139, 0.4481, "UeaWUCaWUCcVUecVU6g/YBg/Y6fqY6aW" },   -- Quel'Danil Lodge
        { "356", 0.6429, 0.2403, "o3JunFKZmpLujiLujGMYjGNtiNOYiqVBhxVBhxYWiNZBlwZBmpaWpTaWqocVr9cVr9Ju" },   -- Seradane
        { "353", 0.3398, 0.7208, "XIm+U6o+U6uSWQu9WswSY6wSartoarpobko+bkm+" },   -- Shadra'Alor
        { "1917", 0.7294, 0.5260, "rhfqqMg/qMiUqoi/s2i/tSgV" },   -- Shaol'watha
        { "351", 0.5909, 0.4221, "iqZBiNZBiNdAj/fqlwfqnFdrnFaWlwZrlwZB" },   -- Skulk Rock
        { "355", 0.4784, 0.6688, "eOk/c5m+bkm+bko+arpoarsTeOsTeOrogAsTgArohVq9hVnpiNnpiNk/" },   -- The Altar of Zul
        { "1886", 0.4957, 0.5260, "eqfqeOfqeOi/g4i/g4fq" },   -- The Creeping Ruin
        { "307", 0.8247, 0.6299, "1tPDzgQYzgRCynRCxSTsuoTsuoWXuLWXuLYWtvYWtvgVtSgVtSiUr9i/r9kUqMm+qMsTr9s9r9vnsavnsas9vgs9v9u9w1vnw1xnsaxnsa27s22RzD2RzD271R271t4Q3C4Q2mxn1txn1tvn1Rvn1Rjp01jp1RdA01dA01br1tbr1tZr1RZr1RYW0YYW0YVB2KSX37SX37Pt3fPD" },   -- The Overlook Cliffs
        { "1883", 0.4264, 0.5909, "cdhqZWkUZWm+c5m+dylpdyiU" },   -- Valorwind Lake
    },
    [774] = { map = 1427,   -- Explore Searing Gorge
        { "1957", 0.2213, 0.7283, "P0o0PDo0PDvsP0w2Tpw2Tpo0" },   -- Blackchar Cave
        { "1959", 0.7143, 0.2129, "nhK/mwK/mwUKoSVUoSXnp0Z6tpbDtpVUv8TBv8MJvLK/" },   -- Dustfire Valley
        { "1442", 0.2512, 0.3922, "QlQuP0QuP0VUPDVUPDgyVLgyWtdWYOdWYOXnWtXnWtQu" },   -- Firewatch Ridge
        { "247", 0.6545, 0.6387, "mwkOkelYkeo0lOp9p0p9p0kO" },   -- Grimesilt Dig Site
        { "1958", 0.6545, 0.7731, "l/p9lOp9lOx/p0x/p0p9" },   -- Tanner Camp
        { "246", 0.4304, 0.5266, "lOYwiLZ6iLbDY/dWXefpXeh7Wth7WtlYZwlYahnqcDnqdllYhalYi8jFi8gymwefmwYw" },   -- The Cauldron
        { "1444", 0.5201, 0.7059, "i8jFhalYcDmhcDp9dlrHdlujhavsjtzJpDzJpDx/lOx/lOo0jtnq" },   -- The Sea of Cinders
    },
    [775] = { map = 1428,   -- Explore Burning Steppes
        { "255", 0.1650, 0.2999, "M0Q8MOQ8M0ZsPuZsQ5X8Q5WMReWMQ5Q8" },   -- Altar of Storms
        { "254", 0.2788, 0.4023, "TOQEReQ8ReWMQ5WMQ5X8PuZsQTZsQ5dLUYibXTibZoe7ZobcYdakYdX8XTX8X4SsZoSsZoR0ZCR0ZCQE" },   -- Blackrock Mountain
        { "2417", 0.7795, 0.7439, "tbnrsRpbs2xSwWxSvwoj" },   -- Blackrock Pass
        { "252", 0.4040, 0.3170, "YdSsX4SsXTX8YdX8YdakZocUb9cUdHX8dtX8dtSs" },   -- Blackrock Stronghold
        { "2421", 0.2105, 0.6243, "N+dLNZdLNZqTN+qTN+sCU+sCU+ibTzgrQ5fzPudL" },   -- Draco'dar
        { "249", 0.8023, 0.4194, "uBR0tbR0tbWMsRXEsRfzumjTw7jTw7hjyGgryrX8w7X8vLVUvLR0" },   -- Dreadmaul Rock
        { "2418", 0.8478, 0.6756, "yGlDvwmzvwsCz1sC0bnr" },   -- Morgan's Vigil
        { "250", 0.5974, 0.3853, "kHQEhyQ8hyX8gnY0gndLhydLhye7pWe7p8dLrGdLrGbcsRbcsRXEnBWMnBUcl3Tkl3Q8" },   -- Ruins of Thaurissan
        { "2420", 0.9161, 0.5390, "xgPMvLQEvLVUw7X8yrX8yGgrw7hjw7jT0bnrz1sC2KsC36pb36nr5Fmz5Fhj3Ve73VY01AX81ATk36Tk36Y04gY04gUc5FUc5qQ8xgQE" },   -- Terror Wing Path
        { "253", 0.5405, 0.5390, "hMe7gCfzfdjTgnlDjilDkHkLjie7" },   -- The Pillar of Ash
    },
    [776] = { map = 1429,   -- Explore Elwynn Forest
        { "62", 0.6969, 0.7966, "qUr3nXtVm4xwn3xwn3yfsSyfsyzPsyu0rzuErTr3" },   -- Brackwell Pumpkin Patch
        { "18", 0.5336, 0.6382, "g+iRfgjwfglOehlOeCppfgppfgqYg+qYg+rIjcrIjcqYlarIlamtkbmtkbiR" },   -- Crystal Lake
        { "88", 0.8601, 0.6526, "yrjBxNjwxNkftRl9twrIuvrIuvr30pr30pqY1oqY1olO0pjw" },   -- Eastvale Logging Camp
        { "57,63,64", 0.3800, 0.8686, "Vru0VLu0Vr2LXJ2LXJ1cZm2LZm26dD26di2LdiwSbkwSbku0" },   -- Fargodeep Mine
        { "60,120", 0.2455, 0.7822, "Qwl9QRl9QRvjSPxwRv3qVL4ZVr3qVryfVLyfVLr3Usr3Uso6UMo6UsmtUMl9" },   -- Forest's Edge
        { "87", 0.4184, 0.6526, "dilOdDl9all9aGo6bFqYeCqYehlO" },   -- Goldshire
        { "797", 0.4952, 0.8542, "eCwSdiwSdi1ceh1cfBz+g+z+g+wS" },   -- Jerod's Landing
        { "9", 0.5624, 0.3789, "diURdDURdDVvcEXOcEdHcjdHcjemdDfVfBfVfggzg+hig+d2k6d2k6gzi8hii8iRkbiRlagzlafVl5fVlaURg+URg+XOgfX9diX9" },   -- Northshire Valley
        { "798", 0.8505, 0.7966, "yrsmyMtVvPtVvPvjwtxwyrxwzqwSzqu00Ju00Jsm" },   -- Ridgepoint Tower
        { "86", 0.8025, 0.4221, "p1WfmZYsmZfVo2iRo2kfp1kfrTmttRmtuQlOyMjwyMiRyriRyraKyMaKyMYswtX9wtXOuvXOuvWf rzemtwfVtwhisyjBrTiRrTfV" },   -- Stone Cairn Lake
        { "1519", 0.2455, 0.2637, "UsKsTtMKOyMKOyM5NzM5M0OYNURUNzRUNzURNUURNUVvK3WfKXaKLWaKL2fVNUfVNUhiOThiOTlOOylOOyjwRQjwRQiRTNiRTNd2UsdHUsbpVrbpWKZbZHaKZHVAaGTiaGPHYIM5YIKs" },   -- Stormwind City
        { "91,54", 0.6297, 0.5806, "l5fVkbhikbmtlamtlarIo2r3p1qYp1oLo2nco2iRm4fV" },   -- Tower of Azora
    },
    [777] = { map = 1430,   -- Explore Deadwind Pass
        { "2697,2938", 0.4600, 0.5300, "YJWyXeWyXeZ2ZhZ2ZhWy gVb5fqb5e+gAc7gAdnkGe+kGe+iDgVhBgVe+hBe+hBb5" },   -- Deadman's Crossing
        { "2562", 0.4733, 0.7300, "bknKaMoMaMqPbkrQbktTaMtTaMxZiYxZiYoM" },   -- Karazhan
        { "2561", 0.5800, 0.6300, "htgAhBgAhBiDe+iDe+nKiYoMiYxZjExZjEwYlHwYmeuVmekGkbjEjEgA" },   -- The Vice
    },
    [778] = { map = 1431,   -- Explore Duskwood
        { "536", 0.2284, 0.7037, "TrlNTCmKP4mKP4nHMunHMup9N/r2PQr2RxwlWNwlWNq5Vkq5WNmK" },   -- Addle's Stead
        { "242", 0.6235, 0.3333, "mARTjeSQjeTNhlTNhlW/i2Y5iNhbi2hbi2jUpKkRpyhbqbhbqbWDrDWDrsRT" },   -- Brightwood Grove
        { "42,576", 0.7593, 0.5000, "yAUJxYUJyAay1Kay1KX82bX82bUJ rDZ1qbZ1pylNrDnHuOnHu2jUwHhbveay" },   -- Darkshire
        { "1098", 0.7840, 0.3333, "tlUJsUVGsUZ1s9aywHaywHY5xYY5xYUJ" },   -- Manor Mistmantle
        { "94", 0.2037, 0.5370, "N/fhNWfhNWlNTCkRTCfh" },   -- Raven Hill
        { "492,243", 0.2037, 0.3889, "PQVGMuX8MuelNWfhTrfhTrelU8elVkdoVkVG" },   -- Raven Hill Cemetery
        { "799", 0.5370, 0.1667, "g8KrfDLndyOdYuOdWNSQRxSQRxRTOnQXOnRTMuRTMFUJHqTNHqWDK1WDLdX8NWX8OnVGVkVGWNWDWNVGYuVGYuUJchUJdKSQjeTNjeSQlXSQlXRTypQXz6Nh1zMk1zKrzRLnyAOdpyNhpyMkkGMki2Kr" },   -- The Darkened Bank
        { "1097", 0.0802, 0.3889, "ITWDHqWDHqayKMelKMmKMumKNWlNMuX8LdX8K1WD" },   -- The Hushed Bank
        { "241", 0.6358, 0.7222, "momKkvoDkGszlXuspyuspymK" },   -- The Rotting Orchard
        { "245", 0.5000, 0.7593, "eapAdypAdyvpeawlhlwlhlusi2uskGszkGq5kvq5kvpAjepAi2q5g8q5g8pA" },   -- The Yorgen Farmstead
        { "121", 0.7963, 0.7222, "u2mKs9pAs9uswHvpxYtvxYp9wvp9wvmK" },   -- Tranquil Gardens Cemetery
        { "856", 0.4753, 0.4074, "b5VGaoW/bQgefrhbfrgeiNfhi2Y5iNY5hlVG" },   -- Twilight Grove
        { "93", 0.3642, 0.7407, "WNoDVkoDWNvpchvpb5pA" },   -- Vul'Gol Ogre Mound
    },
    [779] = { map = 1432,   -- Explore Loch Modan
        { "936", 0.4071, 0.6501, "cLhpaUilZskbYdkbZFuoZsvka7vkcyr2epq7epoJdanNdakbcykbcyhp" },   -- Grizzlepaw Ridge
        { "142", 0.6971, 0.6682, "nTilmEkbk1kbkNoJmsoJnTwfrBwfrBttsQr2tfr2tfkbrBkbqZil" },   -- Ironband's Excavation Site
        { "143", 0.7092, 0.2333, "pyMUpKNPmENPmETvmsTvnTXcoiZTroZTroYYtfYYtfXcv9Xcv9SzvWSzvWQBuuQBuHMU" },   -- Mo'grosh Stronghold
        { "838,925", 0.2258, 0.1789, "SRLZRqMUOkMUOkR4UvSzUvNPSRNP" },   -- North Gate Pass
        { "149", 0.3346, 0.1971, "V/KdUvMUUvSzVXSzV/WhbjVmbjQBaUQBaUKd" },   -- Silver Stream Mine
        { "923", 0.3225, 0.8675, "XOoJUvq7UvuoTgwfTg36VX36VX41aU36aUvkZFuoZFoJ" },   -- Stonesplinter Valley
        { "146", 0.4192, 0.1246, "a7ImaUImaUQBcLQBcLPGkNQBkNMUi+MUiWKdhHKdggMUdaMUcyJi" },   -- Stonewrought Dam
        { "147", 0.8301, 0.6138, "tfhpsQilsQkbtfkbtfr2sQr2sQvkx0vkx0p/zroJzrhp" },   -- The Farstrider Lodge
        { "556", 0.4675, 0.4507, "cyPGbjQBa7e3cyhpdanNfQp/hvp/jmmSk1mSk1kbmsjgnTd8k1aOk1R4jmQB daQBiWQ9i+R4i+VmepWh hvWhjmWhi+dAhvdAhHaOf4ZTf4XchvXc hvgujmgujmiliWkbhHkb" },   -- The Loch
        { "144", 0.3708, 0.5051, "YdbKXOcFXOkbZskbaUilcLhpbje3a7e3a7bK" },   -- Thelsamar
        { "924", 0.2017, 0.7950, "S5nNRCoJRCpEPLpEN8q7N8uoNUuoNU0MN81ISR1ISRzRTgyWTgvkUvuoUvq7UIq7UIpE" },   -- Valley of Kings
    },
    [780] = { map = 1433,   -- Explore Redridge Mountains
        { "97", 0.4770, 0.4201, "ebVbafY9afdrcEdrdphNiWgCiWaJgyaJf/Vb" },   -- Alther's Mill
        { "1000,96", 0.7380, 0.4201, "qNQtopR5opY9nEaJn3kwryjkryiZxSiZxSkwyEkwyEe2xSe2xSbUwgbUwgWnuJVbuJQtryQtryR5" },   -- Galardell Valley
        { "68", 0.3848, 0.5813, "YIcgXWcgWkgCR2gCR2e2NIe2MWgCMWiZVyjkXWqpfNqpgynGiWnGiWkwj7kwj7iZiWgCdphNcEdr" },   -- Lake Everstill
        { "1001", 0.3081, 0.8115, "f/pdfNqpU/qpU/r0REqpQRuLPfuLPfy5R20ER21PWk1PWk0EZt0EZty5cEy5cExthkxthkqp" },   -- Lakeridge Highway
        { "69", 0.2313, 0.4432, "PfaJOtaJOtcgNIe2R2e2R2gCWkgCXWe2XWdrVydrTbaJ" },   -- Lakeshire
        { "95,98", 0.2313, 0.2820, "R2MAREMAQRQtMWR5MWY9N7bUOtaJUNaJUNY9YIY9Y7XyY7UQXWUQWkQtTbPiSoMA" },   -- Redridge Canyons
        { "996,998", 0.3081, 0.0978, "U/GHR2HSR2K0U/PiWkPiYIR5afR5afJpYIJpYIGH" },   -- Render's Camp
        { "997", 0.6919, 0.8115, "n3qpmSr0mS1PrA2buJxtu7qp" },   -- Render's Valley
        { "70,999", 0.5998, 0.4892, "ktWniWXyiWhNj7iZj7l7lgnGlgpdn3pdnEaJopY9opWn" },   -- Stonewatch
        { "71", 0.7534, 0.6273, "skiZn3kwn3qpu7qpu7oSxSnGxSiZ" },   -- Stonewatch Falls
        { "1002", 0.0931, 0.8345, "JNkwHol7G21PJN4yJN7IPf7IQR59QR3mPf3mQRoSN7nGNIkw" },   -- Three Corners
    },
    [781] = { map = 1434,   -- Explore Stranglethorn Vale
        { "123", 0.2932, 0.1993, "VRPmVAPmVARNWFRNWFPm" },   -- Bal'lal Ruins
        { "127", 0.4656, 0.3247, "eGVOd1VOd1WBdTWBdTYbfLYBfLWbeoWBeoVO" },   -- Balia'mah Ruins
        { "1739", 0.2409, 0.5362, "SVecRzfPRzjQSEjqTIjqTajQTafpS3fpS3e2" },   -- Bloodsail Compound
        { "35,312", 0.2723, 0.7556, "SmprRzqeRzrrSmrrSmtrTItrTru4VRu4VRuFV0trVjrrVArrUeq4TIq4TIqE" },   -- Booty Bay
        { "310", 0.4081, 0.5049, "bKecaXfpaXhpb9hpcOgccfgccfeccOe2" },   -- Crystalvein Mine
        { "117", 0.3193, 0.2855, "WFUBVjUaVjVOWWWbXaWbX9VnX9U0XaUB" },   -- Grom'gol Base Camp
        { "1741", 0.3193, 0.5206, "VjcCUvc1UefpV0gcV0i2X9i2XrgDX9fpZBgDZBe2Xre2XaecXacC V0eCWnecWWfpVjfp" },   -- Gurubashi Arena
        { "297", 0.3924, 0.8262, "aos4aFtrYwtrYfyfZSy5ZSzsbKzscOyGcOuFbstS" },   -- Jaguero Isle
        { "125", 0.3454, 0.2307, "XaRNXJRNXJS0ZBTNZBSAYfRN" },   -- Kal'ai Ruins
        { "101", 0.4551, 0.0896, "dCJMcfJlcxMzftMZftJlfcJM" },   -- Kurzen's Compound
        { "37", 0.4081, 0.2071, "bKNmaoOAaoPNaXPNaoSAbsSAcORNcOQabsQabsPNcOPNcOOZ" },   -- Lake Nazferiti
        { "1737", 0.3350, 0.6616, "XJmdW4mdW4nRWWoEWWqEX9qeX9prYfpRYfmd" },   -- Mistvale Valley
        { "129", 0.3715, 0.3012, "ZSU0YwVOYwXOaFWbaFU0" },   -- Mizjah Ruins
        { "105", 0.4969, 0.2777, "fcS0e5TNeoWBfLW0ggW0ggVnhCVnhCTngxTngxS0" },   -- Mosh'Ogg Ogre Mound
        { "1738", 0.2827, 0.6224, "UvlQUelQUenqVjnqVjlq" },   -- Nek'mani Wellspring
        { "100", 0.3506, 0.1131, "X9LMXaLmXaNMZBNMZBMzZ0MZZSLM" },   -- Nesingwary's Expedition
        { "99", 0.3820, 0.0426, "ZjHlZSHlZSIyaXJMaXHl" },   -- Rebel Camp
        { "311", 0.3976, 0.5911, "Z0i2Zji2ZjlQaXlqaomdbbmdbblQb9k3b9kDbKjqbKi2" },   -- Ruins of Aboraz
        { "477", 0.3506, 0.5127, "YOfpXrgDXrhpYwhpZBhQZBgD" },   -- Ruins of Jubuwal
        { "102", 0.2462, 0.1053, "SVJ/RzKZRiNmT8OAUNMzUvMZUNLmUNJ/" },   -- Ruins of Zul'Kunda
        { "103", 0.4656, 0.4265, "eXaCeGabcxabcxeCf+dpf+bPfca1fcaC" },   -- Ruins of Zul'Mamwe
        { "104", 0.2566, 0.2777, "S3RNSERnSETNRRTnRRU0SEVnSEW0S3XoS3Y1TIZOWWY1WnXOWWXOWWWBVRU0VARn" },   -- The Vile Reef
        { "1740", 0.4499, 0.2071, "cfOZcOOZcfQAcOQAb9SAcxSadTTNdTUBe5UBe5QaeXQAeXOzeGOZ" },   -- Venture Co. Base Camp
        { "43", 0.3036, 0.8732, "YwqEYfqEYOrRXJrRWntSVRvSTavsTay5Ri1TRi2HSm2HSV46TI46Tr3tUe3tUe3Ucx3UdT2gdT1TfL1te50GeXzTdCy5cxyGb9yGbKzsZSzsZSy5YfyfYwtraFtraXtSaXseZ0seZjrRZBrR" },   -- Wild Shore
        { "128", 0.4290, 0.3560, "cOXObsXobsZodTZodTXo" },   -- Ziata'jai Ruins
        { "19", 0.6014, 0.1601, "kyHlkhH/hCH/hCOAgPOzgPQAhlRnhlZOpVZOpVIypEIypEH/llH/llHl" },   -- Zul'Gurub
        { "122", 0.2044, 0.1445, "RiLMRRLmP7LmP7OZQMOzSEOzSENmRiNmRiMzRzMzRzLM" },   -- Zuuldaia Ruins
    },
    [782] = { map = 1435,   -- Explore Swamp of Sorrows
        { "76", 0.5931, 0.2371, "l4NhiKQ3iKXjlIXjnXUNnXNh" },   -- Fallow Sanctuary
        { "1777", 0.1426, 0.6294, "MliuLGj1KWqhOEswQTpaQTiu" },   -- Itharius's Cave
        { "300,1978", 0.8401, 0.8474, "rFFtqWFtqWH8moH8moJDrFJDr1LSuELSxyQ3xyTGzRUNzRXj0wZy0wdJ1gdJ1gj10wj10Aqhxyt4uzt4uzzdtU1sqW1sqW36xy36zR1szRzd0wzd1gwH3uu/3uqh4eqh4eZy2/Zy2/TG0AOo0AMZwSKLwSH8r1H8" },   -- Misty Reed Strand
        { "116", 0.0990, 0.3243, "LGR+HYVVHYYrI3ZyI3cBQTdJRDWcO0VVNVR+" },   -- Misty Valley
        { "74", 0.7094, 0.5204, "o2Zyl4dJlIk8monLoHnLo2patUpauznLuza6" },   -- Pool of Tears
        { "1778", 0.8547, 0.4986, "vjXjuzXjuzqh0Aqh0AnL0wnL0wj11gj10wZy0AZy0AXj" },   -- Sorrowmurk
        { "1780", 0.1862, 0.4986, "O0dJOEdJOEiuRyiuRydJ" },   -- Splinterspear Junction
        { "1797", 0.6803, 0.7820, "oHpamoqhnX36qW36qW1sr11sr1pa" },   -- Stagalbog
        { "75", 0.4623, 0.5640, "ecdJdsdJdsfXbdfXbdoTgroTgrdJ" },   -- Stonard
        { "657", 0.2589, 0.3243, "RyTGRDTGRDYrRyZyWQZyVhTG" },   -- The Harborage
        { "1798", 0.4332, 0.3243, "XAQ3WQQ3WQeQdsfXdsdJiKdJiKQ3" },   -- The Shifting Mire
    },
    [802] = { map = 1436,   -- Explore Westfall
        { "219", 0.3619, 0.5357, "YMdzXteiVReiVRhdVwhdVwkYWvkYYMnUZqnUbnkYbngAaJdz" },   -- Alexston Farmstead
        { "921", 0.3429, 0.7357, "XOpgWPqPWPuoYMvWYrt5aJt5aJqPZqpg" },   -- Demont's Place
        { "109", 0.5143, 0.2071, "g+M/gfNueiNueiSGfBSGeiVCibTkibOchdOchdM/" },   -- Furlbrow's Pumpkin Farm
        { "113", 0.3143, 0.4214, "VwaJVRaJVReiZLdzZLa4" },   -- Gold Coast Quarry
        { "111", 0.4381, 0.2071, "bnNubHNubHS1bnS1bnUTfBUTeiNu" },   -- Jangolode Mine
        { "20,919", 0.4286, 0.7071, "djhdcliMdjnUg+mlh8lHh8jqg+jqf/hd bnmlaJoCaJt5eitKeisbfgsbhdpghdoCdEoCclml" },   -- Moonbrook
        { "107", 0.5429, 0.3357, "i7UTf/Vwf/aJg+aJg+a4jaa4j5aJj5Vw" },   -- Saldean's Farm
        { "108", 0.5524, 0.5071, "ibdEf/eif/iMg+jqj5jqk3iMk3dE" },   -- Sentinel Hill
        { "920", 0.4190, 0.8357, "hdpgfgsbeisbeitKYrt5YMvWZqw0ZqzAaozAao0eeD1NeDxjeiw0ibw0ibq+" },   -- The Dagger Hills
        { "917", 0.6095, 0.5929, "k3iMj5i7j5mlkYnUm0nUm0mlpQl2pQiM" },   -- The Dead Acre
        { "922", 0.6286, 0.7500, "nznUnToClXoClXoxhdoxh8q+ibq+ibw0oSw0pQvWpQt5pvt5pvoC" },   -- The Dust Plains
        { "916", 0.5810, 0.1786, "kYLhi7MQi7PLibPLibSGi7S1lXRYlXLh" },   -- The Jansen Stead
        { "918", 0.4476, 0.3643, "dEVwbnXObHaJclcWeicWfga4fgZaf/Zaf/Vw" },   -- The Molsen Farm
        { "115", 0.3143, 0.8786, "UTw0Tzw0TzzAVR1NXt1NXtySWvw0" },   -- Westfall Lighthouse
    },
    [841] = { map = 1437,   -- Explore Wetlands
        { "1036", 0.4982, 0.4845, "b/bLbKbzbKdCZ7dqZ7fhc0e5c0gwe4gwghjOiLjOiLhXhWgwhWdqg8dCe4dCdobL" },   -- Angerfang Encampment
        { "1018", 0.2322, 0.5087, "PndCOydqOye5QbgIQbh/RQjOSFjOSFlFQ2ltQ2m8RQm8RQoLSgoLTUm8TUlFTvlFUJinU+h/U+fhUJeRTUeRS6dC" },   -- Black Channel Marsh
        { "1022", 0.1758, 0.3757, "PMTwOXUXOXVnN9VnN9W2NIYFNIdCS6dCS6caUJcaUJZUQ2Xe" },   -- Bluegill Marsh
        { "1016", 0.6030, 0.2668, "kPQCj1QCkPRRilRRjAWOleZ8oXZ8oXYFniXeniUXoXUXoXTInIRRmTRRl5QC" },   -- Direforge Hill
        { "1038,1037", 0.8690, 0.6417, "vYbzujdCsFdqsFgIu+gIu+hXwninwnlFwNlFwNoLvyozvYoLtuoLtuozq1ozqbpaqBvnqbvnqbxerqyFrqytsFytsFxetUxetuwOujwOuju/vyvnvytwz6twz6rR0vqq0vpa1kpa0ve5yReRxCbz" },   -- Dragonmaw Gates
        { "205", 0.4902, 0.1701, "doNkdONkdOQCdoQqhWRRhWQCiLQCiLNk" },   -- Dun Modr
        { "309", 0.4499, 0.2547, "b/QCbkQCbkVnb/WOfSVnftRRfSQqdoQqdoQC" },   -- Ironbeard's Tomb
        { "150", 0.0952, 0.5692, "KqfhJAhXJAlFJ1mUKqmULEnkMTnkN9lFN9h/MThXLffh" },   -- Menethil Harbor
        { "1020", 0.6111, 0.5571, "lEeRkpeRkpfhjahXj1ltkpmUkpnkpMnkpMinoXinl5eR" },   -- Mosshide Fen
        { "1017", 0.7239, 0.3878, "n9UXniUXniXeoXYFoXakpMbzrQcarQdqs6dqs6dCujdCu+cau+Z8s6Z8sfYFrQYFoxUX" },   -- Raptor Ridge
        { "1023", 0.3612, 0.1943, "X3M8XCOLWNOLVzPaU+PaUkQqTvQqTvShU+UXbkTwbkOLaVNkaVM8" },   -- Saltspray Glen
        { "1024", 0.2322, 0.2789, "Q2RRPMTIQBWOQ2XeSgYFSgYtTvYtUJZUUJbzXCbLX3YFYRYFYRU/X3UXU+UXTvShTvRR" },   -- Sundown Marsh
        { "1025", 0.5466, 0.3757, "iLU/hxVngHVngHbLhWdCjadCj1eRlEcan9caoxdqrQdqrQcapMbzoXZ8leZ8jAWOjAU/" },   -- The Green Belt
        { "1021,836", 0.4902, 0.7506, "hWkeg8keg8ltgHltgHoLeDoLdou/e4vne4ytfSzUj1zUj1wOjavng8wOhWrRilrRilpaj1paj1ke" },   -- Thelgen Rock
        { "118", 0.3531, 0.4966, "ZGakX3bLWodCWoe5WNe5WNhXWoh/YsinYsh/aVhXZ7ak" },   -- Whelgar's Excavation Site
    },
    [842] = { map = 1438,   -- Explore Teldrassil
        { "736", 0.4579, 0.5445, "drghcViBcVkidAlieAlCeAjifWjCfWhB" },   -- Ban'ethil Hollow
        { "1657", 0.2353, 0.5543, "X+fAXpfAXpghW+hhWThhWTjiXTjiXTnjXpnjX+liYplCYphBYUhB Q8hBP7hhP7jiR8jCR8kCSnkCSnjiT9jiT9ihU9ihU9iBT9iBT9hhSShhR8ihRRih" },   -- Darnassus
        { "186", 0.5626, 0.6034, "isjCiXjCisnDkYmjkYlCjtkijtjC" },   -- Dolanaar
        { "261", 0.4055, 0.7802, "a/sFaUslaUtlY+uFY+wmcqwGcVtF" },   -- Gnarlpine Hold
        { "259", 0.5888, 0.6820, "kCmjjCoDgWoDgWqEfrrEfArEfAslgWslgstliCtliCrliXrEjXrEjtslltsFltrEmYrEnDqEnDoDlYnDlYmj" },   -- Lake Al'Ameth
        { "478", 0.3924, 0.6624, "ZpkiZUkiZUnDYpnDYpqEY+qkbVqkbqpkcqpEcqoDb/nDb/ki" },   -- Pools of Arlithrien
        { "702", 0.5561, 0.9177, "isynhs0Ihs5JiX6Kjt6KkY5JkYznjtyn" },   -- Rut'theran Village
        { "188", 0.5626, 0.3284, "jXTcjCT8hBT8gsbfhXb/hXfAhsfgjXfgjXgBlDgBlDfAmDfAmDfgoEfApZc/pZYeoZX+oZWdnuWdnZU9muU9mDT8 kYZelYZelYcfjtb/jtaf" },   -- Shadowglen
        { "260", 0.6673, 0.5838, "mujCmYjCmYkioElCoElipvlipZjC" },   -- Starbreeze Village
        { "264", 0.3662, 0.3186, "ZUScXTTcXTUcV9WdV9X+WTX+W+a/bqafb/Sc" },   -- The Oracle Glade
        { "266,265", 0.4317, 0.4266, "cVScb/Scb/WdbqWdbqafbVafbVdgbqeAdrdgdrafcqafcqW9dAW9dAVddrU9drSc" },   -- Wellspring Lake
    },
    [844] = { map = 1439,   -- Explore Darkshore
        { "447", 0.4364, 0.5992, "b1i7bki7bTk4bDk4bDnOeLnOebi7" },   -- Ameth'Aran
        { "442", 0.3804, 0.4313, "ZOaVY9aVY9b5YLb5YLdEYtddYtePahd2ayddahbHaAaV" },   -- Auberdine
        { "446", 0.4567, 0.3855, "eLX/d6YYc3YYcWZKcWaVcnaVc3b5f/b5gQaughaughZjfeX/" },   -- Bashal'Aran
        { "456,445", 0.5331, 0.3244, "f/Q9fvQ9fvUFgQUegQWCgyWbgyX/jIYYjIWbiWWbh0Vph0UehCTThCQ9" },   -- Cliffspring River
        { "448", 0.4313, 0.7748, "cWssb1tFb1wNdIwNdZtF" },   -- Grove of the Ancients
        { "450", 0.3550, 0.8588, "YtwNX7xYX7zuZOzuZOwm" },   -- Remtravel's Excavation
        { "443", 0.5992, 0.2023, "kbN1jpOOjYShkKTTkKVQleVQluUFl/UFl/ShmgShmxRWnCRWmxOO" },   -- Ruins of Mathystra
        { "449", 0.3855, 0.8664, "aAw/ZOxYZOzuZv0gbT0gbTzubDzubDw/" },   -- The Master's Glaive
        { "444", 0.5636, 0.2634, "jYShimS6imU3i3VQkKVQkKTT" },   -- Tower of Althalaxx
    },
    [845] = { map = 1440,   -- Explore Ashenvale
        { "415", 0.3728, 0.5089, "YdcPXkdkWYeBWYiAW+iAYdkOZCkOZClHaOlHcAidcAfWbtfWbtedbaedbadka0cr" },   -- Astranaar
        { "438", 0.9393, 0.3615, "1cVl03WB0kXzzrXzzraB0ka603cP4acP4ta65Aa65AYs4aXz4HVl" },   -- Bough Shadow
        { "422,432", 0.6561, 0.8211, "skpjrGrVqzt/rGucs3ucs3vVtdvVtdt/upt/upsOuWsOuDqc mqtGleuclLwNklwqklzUlezUle0Nn10Noby4pUy4pUxGpBxGouucnPuc lewNm9wNm9xjmqx/lex/" },   -- Fallen Sky Lake
        { "434", 0.8179, 0.6911, "u8mAupmAupm5u8m5u8q4v1sOwtsOxArVyfrVyfqcx5qAx5oOwanywIm5vim5" },   -- Felfire Hill
        { "417", 0.2688, 0.6304, "TIjyS1jyS1krQwkrQwnVRDnySinyS1oqVMpHVMoOVynVVylHVfkrUBkrTujy" },   -- Fire Scar Shrine
        { "424", 0.4480, 0.4569, "cAZka0bWa0dIbadkcAgPfQgPfQcPdxbWc5Zk" },   -- Iris Lake
        { "441", 0.1879, 0.3875, "OsXzNzYsNza6OZa6PlcrP3edRDedRpdkR8bySPbyRWYPRDXz" },   -- Lake Falathim
        { "413", 0.2688, 0.3528, "TuWeS1XWS1dITbeBUmeBU5dkU5adVMadVMZkVyZIWFXzVfXzVMWe" },   -- Maestra's Post
        { "421,420,2359", 0.5058, 0.7084, "iOlHholkhVnygvnygvm5gJm5fjnydMnyc5oOdMtGfQtGfQuchou4hotjigtGigoqk4oqklmA" },   -- Mystral Lake
        { "428,431", 0.7370, 0.6130, "n1cPnicPnidkoIeBn1kOoIkrpUkrpUi5qzgrrZgrrZdkqzdkqzcrqNcrqNcP rrkOrZkOrZnyqzoqqNoqqNqcrGqcrZpjr+pjr+nys3nVs3kr" },   -- Night Run
        { "426", 0.6098, 0.5089, "klcrj/dIkSgrjshHj/mAk4lkk4krlekOlxidm9hHmqe5lLcr" },   -- Raynewood Retreat
        { "430", 0.8064, 0.5003, "viedupe5upgru8grvPiAv1iAwagrxAgrxAed" },   -- Satyrnaar
        { "419", 0.5116, 0.3962, "fjZIfQZIfQbyhVbyhVZkhCZI" },   -- The Howling Vale
        { "418", 0.3382, 0.6824, "W+mAVynVVysOWYsOWYsqaOsOaOoOZCmcXRmc" },   -- The Ruins of Stardust
        { "416", 0.2168, 0.5263, "OGa6NNbWNNidOGidOGkrOskrOZlHOsmcQwmAQwkrS1krS1jyTbi5UUi5UUiAU5hkU5gPTbe5TbdkS1dIS1byR8byR8crRpcrRpdkRDedP3edPlcr" },   -- The Shrine of Aessina
        { "414", 0.0838, 0.2228, "GsL0GZL0GZNJGsNJG/SBGsSBGsTXF0TXF0UQE7VlE7dkMBdkMBaBMUaBMUZILuYsLuXWMBW6NNXWNzWeNzVlOsVlOsUQOZUQOZS6OsS6OsNlNgL0" },   -- The Zoram Strand
        { "2301", 0.3671, 0.3355, "ZVVIYKVlW+XzWFXzVMaBbtaBbtXWbHWeahWeahVI" },   -- Thistlefur Village
        { "437", 0.8699, 0.5870, "0kfWzFgPzFgryfgryMhkwaidwamcxTm5x5oOyfoOyfny03ny03mA1vkr2Cid2Vid2Vfy2CfW" },   -- Warsong Lumber Camp
    },
    [846] = { map = 1441,   -- Explore Thousand Needles
        { "480,2237", 0.1856, 0.2216, "OjN9NxOjNxQSOjQ4OjSnPUTyRQTyRQQ4 Q4WHQfWHQfYcSCYcSCWs" },   -- Camp E'thok
        { "2097", 0.3447, 0.3580, "X2SnXeSnXeTyV6TyV6bWWTb7ZBb7ZadFa9dFa9awaLawaLZBakZBaLWsa9WHa9TN" },   -- Darkcloud Pinnacle
        { "484", 0.4508, 0.5170, "dSdrc5drc5e1bve1bvhvcgiUcgkEeckEeci6fOhvfOe1ecdr" },   -- Freewind Post
        { "482", 0.1098, 0.3580, "L1U8KSXRKrbWLccgNxb7OjdFQGdFQGawOjaLNxZBNxWsM/Ws" },   -- Highperch
        { "481", 0.4205, 0.3807, "a9WHaLWsaLX2akX2aLawa9awa9b7drb7eDZmdSYccgYc" },   -- Splithoof Crag
        { "485", 0.3220, 0.2443, "XFQ4WsQ4WsSCV6RdV6TyXeTyX2SCXFSC" },   -- The Great Lift
        { "483", 0.3068, 0.4943, "TlcgSCe1S0gATlgATlhKV6hvV6iUXei6X2iUXedF" },   -- The Screeching Canyon
        { "439", 0.7083, 0.7557, "roe1q2faq2glqFglpsnjo6oJpTouo6szm+vHm+32oi32oi4bwr4bxc2r082r08yC2GyC2Gjf2fjf2fiUzAiUynhKx1hKxEgAxEe1 tkiUxciUzAkpzAynynzMv5zMv5ynvHynvgzMvH08tL0WtLynt9ynt9yCszxcszousBnjsBkp nXvHo6vHo6vtqFvtqew3rPw3q2zxqe0WnX0W" },   -- The Shimmering Flats
        { "2303", 0.5568, 0.4716, "hjbWgxcghKfaithvkphKlCfalbfalbcgjfcgjGbW" },   -- Windbreak Canyon
    },
    [847] = { map = 1442,   -- Explore Stonetalon Mountains
        { "2540", 0.6408, 0.9315, "lSzuk7zuk710lS10lS24mV4cnu4cox24oxzu" },   -- Boulderslide Ravine
        { "2538", 0.7705, 0.9111, "uBzNsnzusn2Ws+24uX24va1TvazN" },   -- Camp Aparaje
        { "2537", 0.7500, 0.8496, "sRwErOxHrOzuvxzNvxxovaxovEwE" },   -- Grimtotem Post
        { "2539", 0.7227, 0.9623, "qh0QqL0QqL4+s+5fsn4+sn24r72Wr71TrO1T" },   -- Malaka'jin
        { "464", 0.4838, 0.4299, "fsV3fWWYcjW6cMalc5bGc5crcjcrcjf0c5gWhyf0ifdujidujialhFbGhcV3" },   -- Mirkfallon Lake
        { "2541", 0.5316, 0.7473, "gZpQgCpQgCvBkPvBkPsZjMsZjMpQ" },   -- Sishir Canyon
        { "467", 0.3882, 0.0921, "WnGJVNHtVNKVUgKVUgL6SEMbSESuVjSuVjTPW9SuW9TPYWTPYWTxadTxdmPDdmIPdPIPdPGJ UgL6WnL6XTM9W9PkUgPD" },   -- Stonetalon Peak
        { "460", 0.4701, 0.6040, "c5iccjiccjnJdPoNgZoNgZkAgvkAgZic" },   -- Sun Rock Retreat
        { "465", 0.3268, 0.6654, "Vji9THmoTHrWTdrWTdsZU3ufadt9adqTbJpQbJnJadmoadlDZDi9" },   -- The Charred Vale
        { "1076", 0.5452, 0.6347, "gZf0gCf0gCicgvjfgZkAgZnrhcpQjMpQjMsZkPsZkPvBjivBj4yrkPzNlozNlozuoxzuox10qL10qLxopewlmrvimrufmVufmrrWlSq0lSoNkPnJkPlDjMlDifkAifg3iIgW" },   -- Webwinder Path
        { "461,1277", 0.7705, 0.4607, "kPYej4Yej4ePi1ePi1jfj4jfkPnJlSoNlSq0lorWmrrWmrsZnusZnurWnCrWnCounYounYnrobnroxmoutnJutkivakivai9wdi9wdexxgexxgYetqYetqaDsRaDsRZiqLZAqLbooxdunCdunCfSoFg3rkf0rkhZsni9snkir7kiqhh6p0h6p0icnCicnChZlofSlodMl+crlScJlSZiloZAqLZAqLYe" },   -- Windshear Crag
    },
    [848] = { map = 1443,   -- Explore Desolace
        { "2405", 0.3892, 0.2898, "ZwSrYnT0YnWqahXza5Y8dLYXdLWqbqU9bqT0a5Sr" },   -- Ethel Rethor
        { "606", 0.3744, 0.8791, "Ynt/YPt/YPvIXfvIXfw1XGw1XG1ZX32iYn2iYn3GcC2ica19cayjZYt/" },   -- Gelkis Village
        { "596", 0.5079, 0.6011, "d7g6dLhedLmmdjnKesnKfdoThuoThunvjPnKi3kUiHjwiHinf1inf1he" },   -- Kodo Graveyard
        { "609", 0.7451, 0.4788, "psZgpUZgpUg6q1herOjLuQjLuQinvAinvAbNsvbNsvaEqFaE" },   -- Kolkar Village
        { "2407", 0.6191, 0.4010, "mSY8lJaElJbymqbymqY8" },   -- Kormek's Hut
        { "604", 0.7155, 0.7457, "psnvnzpcnbvtoLwRoLyjsWyjsWw1uQw1uQt/t4t/t4s2uos2uQsSuQqAt4qAt4o4tHnv" },   -- Magram Village
        { "602", 0.5227, 0.7679, "gNpcesqleUvtdLxadL0Qif0QifxajPxajPvtkYt/kYrJjoqAi3qAi3pc" },   -- Mannoroc Coven
        { "608", 0.6636, 0.0896, "nbH3mqIbmSManCM/nCOInzPQpsPQpsNjqdNjqdJkpsJApsH3" },   -- Nijel's Point
        { "2406", 0.2929, 0.0785, "UcJAUEJAUEMaWWMaWWJA" },   -- Ranazjar Isle
        { "603", 0.7600, 0.1786, "svKJrOKtrmL2qdMaqdNjpsNjpsP1qdQZq1UYrmUYr+VhtHVhtHWqvZWqvZVhwiVhwiSGwJSGwJQ+wiQ+wiMawJMavxKttHKt" },   -- Sargeron
        { "2198", 0.8044, 0.7901, "vxruvAs2t4s2uQxaw6xaxSsS" },   -- Shadowbreak Ravine
        { "2408", 0.2484, 0.7012, "TTnKRCo4RCs2Ucs2U0oTUEoT" },   -- Shadowprey Village
        { "2404", 0.5079, 0.1119, "gNIbfEJAfEM/fdM/fdOIi3Osi3M/huL2hWJAgNJA" },   -- Tethris Aran
        { "599", 0.5524, 0.2675, "huQZgNRigNXzglYXkxXzlJXOlJSGkAQZ" },   -- Thunder Axe Fortress
        { "607", 0.3299, 0.5678, "VNfMUcgVUcnvU0nvU0pcX3o4YPnKa5nKa5kUaJkUaJfxZYfxZYfM" },   -- Valley of Spears
    },
    [849] = { map = 1444,   -- Explore Feralas
        { "1099", 0.7518, 0.4281, "sRbZrybwrydPridPryetsxeVtAdPtvdPt/cgufcgtvbZ" },   -- Camp Mojache
        { "2577", 0.5839, 0.4640, "h9bwhtbwhteth9etiNgLjrgLkahql5hSl5f0lpf0lpfFl5fFl5cI" },   -- Dire Maul
        { "1111", 0.5168, 0.0971, "gfKFgPKFf/Mqg+NCg+MTheL7heK0g+KF" },   -- Dream Bough
        { "1105", 0.5408, 0.5647, "hOhqg+hqg+kPhekPhekmjrkmjriwidiZidhq" },   -- Feral Scar Vale
        { "1106", 0.5360, 0.7086, "hOm0g+m0g+pBgvpBgvtEg+tEg+tziNuLiNtzi8tzi8pYidpYidm0" },   -- Frayfeather Highlands
        { "1103", 0.7614, 0.2986, "sBTqryTqryWPsBWPsBW+sxW+sxYcufYcuuZLwcZLwcW+ufW+ufTq" },   -- Gordunni Outpost
        { "1100", 0.6799, 0.3993, "oWZLoGZLoGbZoWbZolcgqTcIrDbBqzZL" },   -- Grimtotem Compound
        { "1121", 0.3106, 0.8453, "RBk+QiltQirmQSrmQivpQSvpQSwwQiwwQiyOQxyOQx3BRB3BRB4fRR4fRR6sa26sbF7EbV59bl59b03wcE3wb0tcbVtEblopb0opb0k+" },   -- Isle of Dread
        { "1137", 0.8429, 0.4281, "wsXtwcXtwcZLuuZLufcgu+cgu+eVvdeVvdgjyqg6yqfc0Ifcz4fFz4dP0YdP0IbZ03aS03Y00YY00IYFxbYFxbXt rDhSqzhSqziBufiBufhS" },   -- Lower Wilds
        { "1113", 0.5120, 0.1763, "h9NxhtNxhtOgfQOIfQPnfwPnf/RdhORdheP+idP+i8PPi8Nx" },   -- Oneiros
        { "2522", 0.5983, 0.7086, "k6iBkqiBkqmEkamEkanLj7nLj7n6jMoSjMpBi8pBi8uLnXuLnXstnHstnHmcmomEmoiB" },   -- Ruins of Isildien
        { "1114", 0.4017, 0.0899, "eSHJeCHgYoHgYoPPcUPPckOIczOIczMqexMqexH4" },   -- Ruins of Ravenwind
        { "1120", 0.2386, 0.4137, "U8VIUtVIUtV3UNV3UNWnSfWnSfW+QiWnQSW+QSXtRBYcRBZjQiZjQiaSPyaSPyc3QCc3PygjQCgjQCiZQxjfQxk+SQk+SQg6SAg6SQetU8eVU8bBV7aqV7aSW6aSW6bBYJbBYYf0WLf0WLgjW6hSW6iwXpiwXpk+b0k+blkmbljIbVjIbVc3a2cIa2bBZnbBZnaqZIaqZIZ7WLZ7WLXWVsW+VsVg" },   -- Sardor Isle
        { "1108", 0.4592, 0.5216, "VcInVMInUtNxU8NxU8P+VMP+VMSMVcSMVMVIVsVgVsW+WLXWWLZ7ZIZ7ZIaqZnaqZnbBa2bBa2cIbVc3bVjIbljIblkmb0kmb0opblopbVtEb0tccE3wb03wb042bl42bl59bV59bF7EdD7EdD5Odi42di3BeC2peSqIexpwexoSfgnjfgj3f/jff/iwg+iZhegjgPgLfwaqehaqehZjeCY0eCXWbVXWbVWna2V3YJV3YJJuW6JuW6JWWLJWWLI+" },   -- The Forgotten Coast
        { "1119", 0.4544, 0.2266, "exHJehHJexIPfBH4isH4isHJ YYHgYJHgYJVgdDVgdDXWeCXWeCY0ehZjehaqhtaqh9XWg+XWgvV3g+Vgh9Vgh9TSisTSisPnidP+heP+hORdf/RdfwPnfQPnfBMqczMqczOIckOIcUPPYoPPYoHg" },   -- The Twin Colossals
        { "1101,2519", 0.6942, 0.6079, "qEf0p0gLo1gLo1iZnXiZnnpYqTpYqTpBrDpBrDpYufpYufkmuukmufiBqziBqzf0" },   -- The Writhing Deep
    },
    [850] = { map = 1445,   -- Explore Dustwallow Marsh
        { "2079", 0.7762, 0.1571, "srJVrsJ0quLSqZONpbONpbRnpwRnqETFrsUDrsVCuTVhuTVCu8VCvmUDv7SmwkSmwkSGy2SGzLONyhONyMMQxOLxwkJ0v7J0v7JV" },   -- Alcaz Island
        { "496,507", 0.4079, 0.1476, "bxJ0aeKTaJLSYhLxYMNOX4NOX4ONaeSGcGRnduPLduLxcwKTbxKT X4UDXjUDXjVhW5VhW5WAXjWAXjW+YMX9ZgX9aJW+aJVCZgUD" },   -- Brackenwall Village
        { "509", 0.3952, 0.6333, "aJlHZglmZgoiZ0pBbIpBbxoCbxmGbIlH" },   -- The Den of Flame
        { "2302", 0.4333, 0.5190, "dEa4cbb2bxb2bIdUaedUaedzY2eyY2hOZLhOY2lmZglmZglHbIlHbIlmfBlHfBlmgUmGgUlHgAlHgAhtgUhtg+eygAeSfrdUfBdUeDa4" },   -- The Quagmire
        { "513", 0.6937, 0.5190, "oIcWnJc1mLeSmLgum0gunJiMoIiroIkooxlmqZlmrsjqrsirsWiMsBdUqEdzpbcW" },   -- Theramore Isle
        { "502,518", 0.6111, 0.1667, "mgHYmLHYmLIWlMIWlMI2j5JVjkKTi7KTi7LShTLxhTPLhoPLhTPqhTRngUSmgUUDfWVhgUWfgUXeg+YciRY7i7aZj5aZlMYclMXelhXemLYcmLZ6nJa4nJc1nzc1nzbXoxa4oxZ6quX9quUDrDTkqETFpwRnpbRnpbONqZONqZNupwMvpwKTpbKTpGIWocHY imTFjkTFjkUDimUi" },   -- Witch Hill
        { "511", 0.5286, 0.7952, "imoih8pghTpggprdessbeDt5aet5azzQdEzvdE0Oh80OimyxjQyxjQxyj5xyj5w0k4vWk4q+kjq+kjpgj5oi bxyxesyxeszQdZzvdZzQbxzQ" },   -- Wyrmbog
    },
    [851] = { map = 1446,   -- Explore Tanaris
        { "1939", 0.4490, 0.4221, "aDXvZzXvZzdraDdraDfibxfichhBffhBf/gRf/figOfigOc8hObdhOatgOZmf/YHffYHffXv" },   -- Abyssal Sands
        { "1938", 0.5359, 0.4583, "hObdgOc8gOfigugRidgRjMfKjMebjseDjcb0jMbd" },   -- Broken Pillar
        { "2300", 0.6422, 0.5018, "npdrnJebmqebmafKlrfKlrhBmKhBmqiIoJiIoohZooeD" },   -- Caverns of Time
        { "983", 0.4055, 0.5525, "aTfiZThBZTj/ZzkWZzmlcBmlcRlecxlGcxj/dBj/dBhBchhBbxfi" },   -- Dunemaul Compound
        { "984", 0.4635, 0.6395, "dQjncxj/cxlGbxmlchnscxqSffqSfvmNevkuegjn" },   -- Eastmoon Ruins
        { "976", 0.5214, 0.2772, "hdRchORchOSLgeTSfvTSfvUCffUCffVhgOV5gOWQh9WQiNVhitVhitTSiNS7iNRc" },   -- Gadgetzan
        { "987", 0.5891, 0.9366, "l6rZlLshk7uAj8vHj8v2jsv2jswmjcwmjcxVjMxVjMyFity0hty0hOwmcBwmbixtaixtaixVV2xVVmwmU2wmUnvfSouXR4tQRJtQQpuAQpuvRJuvRJvfRpvfS4xVTnxVTX0TSY1ySo2iT32iUX1aVW1aV22iWl2iXF1yZj2iZj2KbS2KbS1abx0rcx0reQ25eQ4weg4weg6neQ6/fP6/fP6nf/6nf/6/js6/js6nj86/np6/np0Tn50Tn5zkpozMpos4pYs4pYrZ" },   -- Land's End Beach
        { "1336", 0.7388, 0.4511, "rXYfqHZ+qHb0p4b0poeDpYeDpYgRrHgptVkWu0kWu0ZOtFZOtFY3" },   -- Lost Rigger Cove
        { "1937", 0.5987, 0.2264, "nJO2maPNmKP9k7P9k7QVjcQVjMQsjMS7jsTSjsUCkMUxkrUxk7Tqm6TSm6SLnpRznpQVnZQVnZO2" },   -- Noonshade Ruins
        { "979", 0.4007, 0.2772, "X0P9XkP9XkQsX0QsX0XAZjXAZjXvcxXvcxUxdwTqdwQsbiQVayRzaDRzZTP9" },   -- Sandsorrow Watch
        { "1940", 0.6954, 0.5815, "pYf6pIf6o4hZoZhZoJiIm6iImqjPmajPmal1mKl1mKm9l6m9l6rZpYrZponsuknsuklGu0lGu0kWtVkWrHgpqHgpqHgRpYgR" },   -- Southbreak Shore
        { "992", 0.4103, 0.7120, "aTmlaDmlaDuvaTvHdBvHdBsJcxsJchnsbxml" },   -- Southmoon Ruins
        { "977", 0.6712, 0.2264, "oZNunZOGnZQVnpQVnZTSoJUapYUapYTqqHTSqHREpYQspYPN" },   -- Steamwheedle Port
        { "981", 0.5408, 0.7120, "htkuhOlGhOmNffoEffqSe/qSe/sJfvs4fvuAgeuXgev2itv2jcuvj8uvkrtokrrxk7rxk7qSlLqSlLnUkrnUkrlG" },   -- The Gaping Chasm
        { "982", 0.3427, 0.4728, "YEXAX0XAX0YfXFZmXFb0WlckVmckVmebVWebVWfiVGfiVGhZWFhZWFhwZThwZjgRaDf6ZzXvZjXvZjXA" },   -- The Noxious Lair
        { "980", 0.2799, 0.6540, "UXl1TXmNTXqqT3rZVGrCVWpjWVpLWVocWlocWlm9V2l1" },   -- Thistleshrub Valley
        { "990", 0.3572, 0.7699, "Y0qqXFshXFtoWluAWlv2aTv2aTwOcBv2cBvHaTvHaDuvaDrCZzqq" },   -- Valley of the Watchers
        { "985", 0.6084, 0.4076, "m6TqmqUClbUClLVJkMVhkMYfjsY3jsZ+jMaVjMb0jcb0jseDkbfKlbfKlrfilrfKmafKmqebnJebnZdroodToockoJcMn5aVnpaVnpTq" },   -- Waterspring Field
        { "986", 0.6857, 0.3207, "o4V5ooV5ooXYpIYHp4YHqHXvqHV5" },   -- Zalashji's Den
        { "978", 0.3717, 0.1033, "V2HbVmHbVmJRWFKBWFMPW1NXXVNXXkOGYEOGYUPNZTPlZjREaDRzayRzbSREbSO2biO2biNubxNubxI6bSI6ayIKZjIKZDHb" },   -- Zul'Farrak
    },
    [852] = { map = 1447,   -- Explore Azshara
        { "1227", 0.7835, 0.6482, "m8XsmmXsmmZNl7aNjPaNikbOikdPlQdPlQdvmRePmRfQmmfQmmlUlmm1j6mUjPlUjPkTikjzikePhjePhOewhOkzhjkzhjmUi5mUjPnVklnVlQrXpSrXp9sYrps4r/t5sqt5uAv6uVy8vWy8vWzcwsz8xCzcxCw6xtwayYsYytsYytrXzYqXzYm10EmU0EkT1aiS1aaNzuaNzDZNzDXsxtXsxtYsxXYsxXdPvAgxsUgxrUewqpewqpZtqTZtqTYsp9YM" },   -- Bay of Storms
        { "2497", 0.7638, 0.2046, "q+LlqpLlqpQHp9RIn8SImmUqnnUqnnUKrUUKrUWrqpWrqpXLr/XLsUVqwsVKxXUKxXTJytRoytPnxtOGwsOGwBNFurNFurMltqMltqMF" },   -- Bitter Reaches
        { "1216", 0.4022, 0.3229, "bKTJZ0TpZ0UqZJVKYzWrXzWrXzZtYIaNcgaNcgYsdLXsdLUqcLUKb1TJ" },   -- Blackmaw Hold
        { "1233", 0.2970, 0.6975, "UGmUSao2SasYTbt5Ubt5UbuZXdt5Xds4ZJq3ZJoVYIm1Xdm1XdmU" },   -- Forlorn Ridge
        { "1236", 0.2050, 0.5989, "REiSQDiyQDjSPDjSPDn1Pun1QDo2Rvn1Rvm1Swl0SwjzSEjSSEiS" },   -- Haldarr Encampment
        { "1230", 0.9215, 0.1356, "bfFha0GBa0HiafHiafJDaJJDaJLEZ0LEZ0PnaJQHdhPndhPHfMOmfiNFjPNFj6MFm8MFm8LltqMFtqMlxtOGytPnytRoxXTJxXUKytUKzDVK1EUq2FWL2FZN1aZt1adv2wdP3bcO3bbO4baN4xUK5HUK5HTJ4xTJ4xLE3wKE3wJD2wJD2wIC0vHi0EFhonFhonGB" },   -- Jagged Reef
        { "1234", 0.3891, 0.7961, "Zeo2ZJo2ZJq3Xds4XdzcZezcaJ0cdL09dLzcdhzcdht5dLt5dLsYc2sYc2qXb1p2b1pWbfp2aJp2" },   -- Lake Mennar
        { "1219", 0.5863, 0.1750, "kPMFjPMljPNFfiNFfMOmehOmehRIgNRogNSpg4Spg4SIkPSIk6TpmmUqonRommRom8MF" },   -- Legashi Encampment
        { "1232", 0.7177, 0.8651, "p9uZpouZpov6onvaonwaoSwaoSx7pox7pSy8p9zcp90co90co9zcoSy8oS0cnR09nR19qp19qp1dr/09r/z8s/zcsqxbr/xbrUwarUuZ" },   -- Ravencrest Monument
        { "1221", 0.3365, 0.5693, "ZeaNZJaNZJcvYedvXzdvXdfQVxfwVxgxVcgxVcmUXdmUZJo2Z0o2aJp2bfp2b1o2dho2dhm1dLmUb1mUb1kzbKjzZ0jzZejSZegRaJfQb1fQcLewb1bOcgbOcgaN" },   -- Ruins of Eldarath
        { "1235", 0.1524, 0.7270, "OYp2MssYMstYOCtYPDr3PDq3" },   -- Shadowsong Shrine
        { "1231", 0.4811, 0.5890, "cggRcLgRcgiyb1iyb1jScgjScgkTb1kzb1mUdLmUdhm1d2q3eMrXehq3giq3g4r3iksYjPtYk6tYk6uZmmuZmmt5nRt5nRs4ons4onuZrUuZrUwar/xbsqxbs/y8uVy8uAv6sqt5r/t5rps4p9sYpSrXlQrXklnVjPnVi5mUhjmUhOgR" },   -- Southridge Beach
        { "1226", 0.7638, 0.4313, "sUYsqpaNqpewrUewsUgxvAgxxXdPxXZNwsZNwsYs" },   -- Temple of Arkkoran
        { "1220", 0.5666, 0.2736, "hOSIgiSpgiWLg4Wrk6Wrk6TJkPSI" },   -- Thalassian Base Camp
        { "1256", 0.7769, 0.9538, "hOybgizcdLzcdL09cg09cg6gc27AxX7AxC09ws09wsz8wBz8vWy8s/y8sqz8r/z8r/09rU09qp19m819m82+lm2+lQ1dmm1dmm09gi1dgiz8ikz8iky8" },   -- The Ruined Reaches
        { "1228", 0.4745, 0.4313, "lQTpk6Tpk6WrhjWrhjZthOaNgNaNg4ZNg4YMgNYMgNXsfMXsfMYscgZtcgbOb1bOb1cOcLcOb1fwcLgRhOgRhOewikePikbOjPaNl7aNmmZNmmXsp9YMqTZtq+aNr/YswsYswsZNxXZNxtXszDXszDWLzYWLzYVKytUKxCUKwsVKtqVKtqVqsUVqr/XLqpXLqpWrpSWrpSWLnnWLnnUql7Uq" },   -- The Shattered Strand
        { "1229", 0.9018, 0.3327, "0EUqzDWLzDZNzuaN1aaN2FZN2FWL1EUq" },   -- Tower of Eldara
        { "1225", 0.4745, 0.2637, "d2PHdhPnafQHa0TJb1TJcLUKdLUqdLXsc2XscgZtdhZteMYsfMYsfMXsgNXsgNYMg4YMg4ZNgNaNhOaNhjZthjWrgiWLgiSpgNSpgNRoehRIehPH" },   -- Ursolan
        { "1237", 0.2182, 0.5102, "REcvQucvQZhyQuiSSwiSTFhyTFcv" },   -- Valormok
    },
    [853] = { map = 1448,   -- Explore Felwood
        { "1765", 0.4217, 0.4826, "bjdjbQdjbQgOcJgOcvhjd7hjd7gOdVfVcvfVcvdj" },   -- Bloodvenom Falls
        { "1761", 0.4797, 0.9261, "fHyedo0Qdo1ldV1ldV3XeO4tft4tgA3Xgl27gly6gSye" },   -- Deadwood Village
        { "2479", 0.5145, 0.8130, "gluBe0wPe0xIfaxIgAyBhLyBhLxIhxwsiEvW" },   -- Emerald Sanctuary
        { "1762,1769", 0.6246, 0.1000, "kvILkcILkvNFlVN+oTNhoTLvoALvoTLToTJhnaJhnaIL" },   -- Felpaw Village
        { "1767", 0.5319, 0.2304, "glNhftN+fHO3fHPweOQpeORidCS3dCUNd7Upd7V/e0W4e0XwfaXwgAYphLYNiEWbi9Wbi9V/j2WbkcVikcSbkvSbkvRFlCRFlCPTkJPTjjN+" },   -- Irontree Woods
        { "2480", 0.4159, 0.8652, "ZeudZLudZeyBaqzzbQzzbQ0sb20scc1ldo1ldo0QdCzzdCyBccxIbQxIaXvzaXud" },   -- Jadefire Glen
        { "2618", 0.4333, 0.1696, "doLvbjMobjNhaEPwaEQpZeQpZeS3aXS3a9RidVR+d7RFd7PwfHN+ehNhehMMdoMM" },   -- Jadefire Run
        { "1763", 0.3754, 0.5870, "ZLhjY4hjYli5X/i5XGkOXGmdXsmdXsm5aXm5aXmdbjmAbjiAbQhj" },   -- Jaedenar
        { "2478", 0.5783, 0.8826, "iEvzhLxIhLyBiXzXiq2Clo2CloyBlCyBkJvz" },   -- Morlos'Aran
        { "2481", 0.3812, 0.7000, "XGlkWzlkWzm5Wgm5WgqAWzqAWzq5X/q5X/sPYSsPYltkaEuBbQsPb2sPb2rWcJrWcJnybjm5Xsm5XsmdXGmd" },   -- Ruins of Constellas
        { "1766", 0.4507, 0.3957, "dVWbccW4ccXwbQXwa9YNa9ZiaXZ/aXbxaqbxa9djcvdjcvfVehfVfad/fadGftdGftcNgSbUgSZGgAZGgAYNehXwd7Wb" },   -- Shatter Scar Vale
        { "1998", 0.6246, 0.2478, "oAPTnaQMlVQMlCQplCRikcSbkcVioTViomPT" },   -- Talonbranch Glade
    },
    [854] = { map = 1449,   -- Explore Un'Goro Crater
        { "537", 0.4910, 0.4932, "hJZxcFb2cFixdAkJeYkJeYk1iEkJiilij6lij6ixjdixj6cijdcijdbK" },   -- Fire Plume Ridge
        { "543", 0.2748, 0.5338, "PKciOtciOtm6XAm6XAmOZxmOaPliaPgsZxgsZxfTY2d7Xed7XedOWFdOWFci" },   -- Golakka Hot Springs
        { "1943", 0.7973, 0.3581, "tmVntJVntJZFtmZFuEdOxSdOxSXsw1Xsw1WUwXVn" },   -- Ironstone Plateau
        { "538", 0.5180, 0.2365, "gOHyfxHyfxKjeYLPd7NUbnNUbKOAbKSKciS2cibKe2bKe2adgsadgsZxiEZxiibKjdbKkYZFmOZFmOXso/Tjo/QFoEQFoEQylwQylTQFlTHy" },   -- Lakkari Tar Pits
        { "539", 0.3468, 0.7365, "XemOXAm6TUm6TUrEUsrEUsv6XewmYZx/YZ0DY20DZU2Idd20ddvNd7vNd7tJcFrEcFprbKoTZxnmZxmO" },   -- Terror Run
        { "1942", 0.6982, 0.6014, "kYdOj6dOj6fTjdfTj6qYkYqYkYrwlTsclTt1mrv6nJ1coi1coi0wp60wqYtJu/t1v6scv6oTxSmOxSdO" },   -- The Marshlands
        { "540", 0.5090, 0.8446, "gOrEddvNdd4Njd4NjdvNiiuhiErw" },   -- The Slithering Scar
    },
    [855] = { map = 1450,   -- Explore Moonglade
        { "656,2361", 0.5208, 0.4817, "dvRNc/RNc/UibhVpcQegZTegZTi8c/i8c/lKgsmRgsrzjprzjpofmmofnWnYnWi8l3h1l3egnWdZnWbLlIbLkYY+i6Y+lIVplITb" },   -- Lake Elune'ara
    },
    [856] = { map = 1451,   -- Explore Silithus
        { "3425,3097,2739", 0.5132, 0.4700, "gbWAe9WveeY8d+Y8d+b5e9b5eecoeegTf8hCf8hxiYigjXhCjXdXh5b5h5ZsjXZsjXY8iYY8 ZkabYlbKYGeGZkgTbCgTcgeGcgcobCab" },   -- Cenarion Hold
        { "2744,3427", 0.5801, 0.8000, "iYm6g6oYgbrUe9sye92Vfc3Eha3Eha3zj23zj22Vow2Vowm6 bCyqajyqaj1mcB1mcByq" },   -- Hive'Regal
        { "2743", 0.2548, 0.5848, "Pxb5PSb5PSqlOyrUWorUXHpHXnpHXnmLYGmLYGhCXnhCXnfkVKb5" },   -- Hive'Zora
        { "2738,3077", 0.6280, 0.5274, "wGMduJNMuoSVxkSVxkN7xFN7xFMd mybKl0coj2dXj2e1jXe1jXmLj2m6qOm6qOeGowb5" },   -- Southwind Village
        { "2740", 0.2261, 0.1686, "PxIyPSIyPSOqRPRmULQ3ULOqVpNMWJKQUrKQUrJhTMJhTMIy QwJhSOJhStLuQwMdQQLu" },   -- The Crystal Vale
        { "2737,2741", 0.2931, 0.9148, "UryqTMzZRu1mRu3zYG3zYG1mWJyq" },   -- The Scarab Wall
    },
    [857] = { map = 1452,   -- Explore Winterspring
        { "2256", 0.5869, 0.8486, "iKsQhcs+hctsguuDguw8gAyBfCyBfC4JiZ43iZ4gj24gkU3ylS3ylS3blx3bmP2tnc2tn71/n70Loaz0oazGo5zGpXyYpXs+nss+nssnmAsnmAsQ" },   -- Darkwhisper Gorge
        { "2255", 0.6103, 0.3697, "lCXtkkYEkka9mPbUmuaOnNaOnNYymfXt" },   -- Everlook
        { "2246", 0.3474, 0.3697, "YTW/YEXWU8XWU8YEUdYbUdZgUtZgUtalVLa9VLbrZwbrZwbUbMa9braObrXWYTXW" },   -- Frostfire Hot Springs
        { "2241", 0.5117, 0.1232, "eUINeEINeESTgASTgAR8guRlguQ3hrQfh7PxjHPxjmPDjmKAjXJpiKJpiKIN" },   -- Frostsaber Rock
        { "2249", 0.6479, 0.7007, "jmm2jXm2jXr5lCr5lSq0mPqdlhrilhsQmAsQmAsnoas+oasQpIsQpIoSmuoSmfn7mfpAmPpAmPoSlxoSlxm2" },   -- Frostwhisper Gorge
        { "2247", 0.6761, 0.4542, "ncZ3mfalmfbUnscwnsi4nNjmqVjmqVa9oaa9n7Z3" },   -- Ice Thistle Hills
        { "2251", 0.5305, 0.4049, "g9ZJgPZggAaOfCalfCbUfwcCfwcwiZcwipcCj2cCj2dHkFdHkFaOj2Z3jXZ3jHZJ" },   -- Lake Kel'Theril
        { "2245", 0.5775, 0.5176, "iZeMh7ejh7gXiKgXiKjPipjPipjmlhjPlhihmAihmPhcmuhFmue6mPeM" },   -- Mazthoril
        { "2250", 0.6526, 0.6162, "nNjmmuj9mukrmPlamPnkmuoSpIoSpXlxpnlxpnjm" },   -- Owl Wing Thicket
        { "2253", 0.5117, 0.2852, "guRlfRTYfRWogPXtgPYyhMYbhrXthrW/h7W/hrSThcSThcRl" },   -- Starfall Village
        { "2242", 0.6385, 0.1655, "ncMimPOVmPPDmAPDmPQInNQInNPxn7PaoKOVo5OVo5M5opMi" },   -- The Hidden Grove
        { "2243", 0.4225, 0.4401, "brbUatbraOcZYjcZYjejeUejeUcCeEcCeEbU" },   -- Timbermaw Post
        { "2244", 0.6714, 0.3415, "oKVLnsV6muV6muYbnNYynNZ3n7Z3oaa9qka9qkWRqVWRqVVL" },   -- Winterfall Village
    },
    [62354] = { map = 2548,   -- Explore Riverglades
        { "16726", 0.6512, 0.1804, "oRLJn6LrmKLrmKMvlGMvlGQ9lzRflzSimgTmpUTmqYSBqYMvqBMvprLJ" },   -- Bolder'ok
        { "16737", 0.2869, 0.6237, "V+fNVRfvU6hUUNhUUNgQT3gQT3i5TKjbTKkfSGmEQsmEP/npPSnpPSotOlpwO8r3P/rWP/sZSGs7Szr3T3r3T3q0XBq0XBoLYFnpYFiXYyh2YygQXBgQXBfN" },   -- Bristle Hills
        { "16724", 0.6375, 0.8299, "mKt+lGvklGwnkZxJkZzQkvzym3zym30UoR02oRzyo+zQpUvko+vkont+" },   -- Farholde Keep
        { "16735", 0.4450, 0.8093, "dXs7a5wGbQxrdtyNdtxrfHxJfevkexvCext+eEs7" },   -- Meadowsbrook
        { "16727", 0.7612, 0.5206, "tMerryfvryi5tijbtikfumlAumliwAliwWlAwAgyu8fN" },   -- Powderfuse Port
        { "16743", 0.5893, 0.4588, "jsckjVckjVfNlzfNlzdGlcck" },   -- Rog'mar
        { "16723", 0.4656, 0.4794, "dtcCcTeJcTgQdAgydAj9eajbexhUhOgyh7fvh7fNhOfNgLdof0cC" },   -- Sunnyglade
        { "16729", 0.6031, 0.6443, "kvmmkCnHkCotlGotlGoLmKnpmKmm" },   -- Terral's Watch
        { "16736", 0.3900, 0.6134, "Z1i5YbkfYbnHYynHZIpPbmotb9oLb9mEcTmEbmi5" },   -- Turner's Logging Camp
        { "16685", 0.2869, 0.4278, "UkYWTgY4TgadSzadSzeJTgerUNhUU6hUVnfNXBfNYFdoYFcCVnYW Olq0OOq0OOsZOlsZ" },   -- Twilight's Shroud
        { "16725", 0.5412, 0.7577, "iSq0g4sZg4ughOvCjVvCjVt+jst+i/q0" },   -- Wheeler's Grange
        { "16731", 0.7612, 0.3660, "u8UIuPVLtMVLtMVtsIVLsIWPrbWPquY4prZ7qubgquckuPdGwWZ7wWVt" },   -- Windstead
    },
    [62356] = { map = 2482,   -- Explore Mount Hyjal
        { "17145", 0.3629, 0.4698, "WSXdVTY7UUY7T0aZS1aZS1cnUzfjVyfjVyldcqj/cqhxeJhCeJfjdpfjdpeFcqeFcLbIbMZqaNZqZOXd" },   -- Cradle of Tranquility
        { "16866", 0.5741, 0.3834, "lBQ0jDRjjDSSeJTBeoYMeJYMeJaZdKbIdKeFeogTikhCikhxjihxkhjPm/jPm/fjn9e0n9dWo8dWp7b4p7Y7o8YModSSneQ0" },   -- Dae'gun
        { "16848", 0.1326, 0.4986, "O6bIKfdWKfhCK+hCLej/OakuPZjPPZhxP5hxP5bI" },   -- Elderwild
        { "17050", 0.4685, 0.7291, "cqmMbrm7brpJbMpJatsGZOs1ZOuTaNvxbrvxcqyueJyueoxQhFxQhltkiEtkhlnqgmnqgGmM" },   -- Felblood Scar
        { "17144", 0.3245, 0.7003, "SWldQ4m7Q4oaRXoaRXp4SWqnSWsGTVtkZOtkZOs1atsGatqnbrpJbrm7Vym7VToaT0oaTVld" },   -- Malorne's Retreat
        { "16868", 0.2478, 0.5275, "SWcnQ4eFQ4j/TVkuT0oaVToaVTm7Vym7VyfjUzfjTVcn" },   -- Mourning's Rest
        { "16867", 0.5357, 0.5851, "eogTcqhxcLmMgGmMgmnqjDoajimMkCmMkCjPkhigjiigikhC" },   -- Shrine of Aviana
        { "16849", 0.7660, 0.3546, "p7QFodRjodVPo8VPo8YMp7Y7p7b4o8dWn9dWn9e0nee0negTo8igqbigqbhxr5hxs4gTv1fjv1eFzRZqzRV+xyV+wUSSt3TBt3Rjs4Rjr5QF" },   -- Summit of Eternity
        { "16853", 0.6029, 0.7291, "m/m7jDoaiEp4iEtkhltkhFx/kCx/lgvxmfvxm/uTq6vCsYs1sYqnqbnqnenq" },   -- Tainted Foothills
    },
    [63684] = { map = 2652,   -- Explore Shen'dralas
        { "16677", 0.7195, 0.3049, "jVLZifLZifQZnfS5mqbonfc4u+c4u+PJuJPJuJLZsfLZsfMp" },   -- Bristleback Retreat
        { "16678", 0.3293, 0.4512, "YgX4XrX4W2boVLboVLgnYggnaLeIaLX4" },   -- Evenshade's Overlook
        { "16742", 0.7033, 0.7439, "pJkXnflnoUpXl0qnl0vmmqw2tUw2tUlnp/ln" },   -- Forlorn Gardens
        { "16675", 0.6220, 0.5488, "kKfYjVfYjVkXnfkXnffY" },   -- Magram Front
        { "16676", 0.3293, 0.7683, "WApXVLpXVLuWWAvmaLvmaLr3W2r3W2pX" },   -- Outcast Hideaway
        { "2657", 0.4431, 0.2805, "W2I5UWLZUWPJRBQZRBc4VLc4VLboXraYXrX4aLX4aLaYcqaYcqboifaYifc4kKc4kKeInfc4mqbonfS5jVRpifPJZVPJZVKJ" },   -- Valley of Bones
    },
}
