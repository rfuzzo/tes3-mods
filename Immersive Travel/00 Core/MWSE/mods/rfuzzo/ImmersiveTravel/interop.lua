local this = {}

-- Please generate a short text a guide NPC in Morrowind would say about this location.
-- Keys are in the format "(-x, -y)" where x and y are the coordinates of the location.
-- Note the whitespace!



---@type table<string,string>
this.quips = {}


-- insert to table
function this.insertQuip(key, text)
    this.quips[key] = text
end

return this

-- Reference
--[[
Seyda Neen  (-2,-9)
Moonmoth Legion Fort  (-1,-3)
Caldera  (-2,2)
Berandas  (-10,9)
Koal Cave Entrance  (-11,9)
Gnisis  (-11,-11)
Ald Velothi  (-11,15)
Ashalmawia  (-10,15)
Khuul  (-9,17)
Ashurnabitashpi  (-5,18)
Urshilaku Camp (-4,18)
Odai Plateau  (-5,-5)
Ald Redaynia  (-5,21)
Vas  (0,22)
Sanctus Shrine  (1,21)
Rotheran  (6,18)
Mzuleft Ruin  (6,21)
Dagon Fel  (7,22)
Ald Daedroth  (11,20)
Ahemmusa Camp  (11,16)
Tel Vos  (10,14)
Vos  (11,14)
Hla Oad  (-6,-5)
Tel Mora  (13,14)
Nchuleft Ruin  (8,12)
Zainab Camp  (9,10)
Falensarano  (9,6)
Yansirramus  (12,4)
Tel Aruhn  (15,5)
Sadrith Mora  (17,4)
Wolverine Hall  (18,3)
Tel Fyr  (15,1)
Holamayan  (19,-4)
Ashurnibibi (-7,-4)
Nchurdamz  (17,-6)
Tel Branora  (14,-13)
Molag Mar  (12,-8)
Zaintirais  (12,-10)
Mzahnch Ruin  (8,-10)
Bal Fell  (8,-12)
Vivec  (3,-11)
Ebonheart  (1,-13)
Pelagiad  (0,-7)
Fields of Kummu  (1,-5)
Hlormaren  (-6,-1)
Arvel Plantation  (2,-6)
Dren Plantation  (2,-7)
Ald Sotha  (6,-9)
Marandus  (4,-3)
Bal Ur  (6,-5)
Suran  (6,-6)
Telasero  (9,-7)
Mount Kand  (11,-5)
Mount Assarnibibi  (14,-4)
Nchuleftingth  (10,-3)
Gnaar Mok  (-8,3)
Erabenimsun Camp  (13,-1)
Uvinth's Grave  (10,-1)
Ghostgate  (2,4)
Buckmoth Legion Fort  (-2,5)
Ald'ruhn  (-2,6)
Bal Isra  (-5,9)
Maar Gian  (-3,12)
Falasmaryon  (-2,15)
Valenvaryon  (-1,18)
Kogoruhn  (0,14)
Khartag Point  (-9,4)
Zergonipal  (5,15)
Tureynulal  (4,9)
Odrosal  (3,7)
Dagoth Ur  (2,8)
Vemynal  (0,10)
Andasreth  (-9,5)
Balmora  (-3,-2)
]]
