"""Band fractions of the Vigil's FULL height, shared by the mesh and its trim
sheet so the two cannot drift. V on the mesh is world height over this total, so
every fraction here is a real height on the building."""

TOTAL = 11.61   # ground to the top of the smoke
PLINTH = 0.42 / TOTAL
WALL_TOP = 4.60 / TOTAL      # the eaves
CORBEL = 5.05 / TOTAL
ROOF_TOP = 7.60 / TOTAL      # the ridge
