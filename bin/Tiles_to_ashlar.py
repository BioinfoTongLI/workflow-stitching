from tifffile import TiffFile
from os.path import join
from glob import glob
import numpy as np
import tifffile
import fire
import pandas as pd

import xml.etree.ElementTree as ET



def OpenTiff(file_path):
    with TiffFile(file_path) as fh:
        img_data = fh.asarray()
        imagej_metadata = fh.imagej_metadata
    return img_data, imagej_metadata


def GenPosList(TileConfFile, FolderWithTiles):
    
    filelist = glob(join(FolderWithTiles, "*.tif"))
    file_path = filelist[0] #take any tile image
    NS = {"ome": "http://www.openmicroscopy.org/Schemas/OME/2016-06"}
    print(file_path)
    with TiffFile(file_path) as fh:
        ome_md = fh.ome_metadata
    root = ET.fromstring(ome_md)
    for md in root.findall("ome:Image", NS):
        pixels = md.find("ome:Pixels", NS)
        pixelsize_x = float(pixels.attrib["PhysicalSizeX"])
        pixelsize_y = float(pixels.attrib["PhysicalSizeY"])
        pixelunit_x = pixels.attrib["PhysicalSizeXUnit"]
        pixelunit_y = pixels.attrib["PhysicalSizeYUnit"]
    
    AllPos = pd.read_table(TileConfFile, sep=';', header=None, usecols=[0,2], skiprows=1, index_col=0).squeeze()
    positions = []
    for i in range(len(AllPos)):
        #print(i)
        posX = float(AllPos[i].split(',')[0][1:])
        posY = float(AllPos[i].split(',')[1][:-1])
        pos = (posY, posX, pixelsize_y, pixelsize_x, pixelunit_y, pixelunit_x)
        positions.append(pos)
    return positions

def PrepImgArray(folder_input, NamePrefix):
    imgs = []
    ListOfTifs = glob(folder_input + '/*.tif')
    ID_list = range(len(ListOfTifs))
    for TileID in ID_list:
        numstr = format(TileID, '04d')
        NameSearch = NamePrefix + numstr
        
        FullPathImage = [s for s in ListOfTifs if NameSearch in s]
        print('Collecting data from tile %d' %TileID, ' / %d' % len(ID_list), end = '\r')

        #read image and metadata
        img, imagej_metadata = OpenTiff(FullPathImage[0])
        imgs.append(img)
    return imgs


#taken from https://forum.image.sc/t/python-tifffile-ome-full-metadata-support/56526/10
def write_tiled_tifs_ZProj(imgs, positions, out):
    with tifffile.TiffWriter(out, bigtiff=True) as tif:
        i=1
        for img, p in zip(imgs, positions):
            print('Writing tile %d' %i, ' / %d' % len(positions), end = '\r')
            metadata = {
                'Pixels': {
                    'PhysicalSizeX': p[3],
                    'PhysicalSizeXUnit': p[5],
                    'PhysicalSizeY': p[2],
                    'PhysicalSizeYUnit': p[4]
                },
                'Plane': {
                    'PositionX': [p[1]-positions[0][1]]*img.shape[0],
                    'PositionY': [p[0]-positions[0][0]]*img.shape[0]
                }
            }
            i=i+1
            tif.write(img, metadata=metadata)
            
            

def main(input_folder, file_out, name_tile_pos = 'TileConfiguration.txt'):
    # usually first ome.tiff contains all metadata regarding tiles positions
    Prefix = 'Tile'
    file_tile_pos = input_folder + '/' + name_tile_pos
    Positions = GenPosList(file_tile_pos, input_folder)
    Images = PrepImgArray(input_folder, Prefix)
    write_tiled_tifs_ZProj(Images, Positions, file_out)
    
    
if __name__ == "__main__":
    fire.Fire(main)
