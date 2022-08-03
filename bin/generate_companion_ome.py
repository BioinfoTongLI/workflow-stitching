#! /usr/bin/env python
# -*- coding: utf-8 -*-
# vim:fenc=utf-8import argparse

from pathlib import Path
from tifffile import tiffcomment
from xml.etree import ElementTree as ET
from ome_model.experimental import Plate, Image, create_companion
import argparse


def get_perkin_elmer_namespace(xml_file):
    import re
    metadata = ET.parse(xml_file).getroot()
    default_namespace = re.findall(r'^{(.*)}',metadata.tag)[0]
    print(default_namespace)
    return default_namespace


def main(evaluation_input_data_file = "index.xml", images_path = "."):
    pe_ns = get_perkin_elmer_namespace(f"{images_path}/{evaluation_input_data_file}")
    NS = {
        "PE": pe_ns,
        "OME": "http://www.openmicroscopy.org/Schemas/OME/2016-06"
    }
    print(f"[*] Reading EvaluationInputData xml")
    metadata = ET.parse(f"{images_path}/index.xml")

    # collect plate information
    print(f"[*] Reading plate")
    plates = metadata.findall("./PE:Plates/PE:Plate",NS)
    assert len(plates)==1, "Expected only one plate"
    plate = plates[0]
    plate_name = plate.find("./PE:Name",NS).text
    plate_rows = int(plate.find("./PE:PlateRows",NS).text)
    plate_columns = int(plate.find("./PE:PlateColumns",NS).text)
    print(f"- Plate Name: {plate_name}")
    print(f"- Plate Rows: {plate_rows}")
    print(f"- Plate Cols: {plate_columns}")

    # gather all images
    images = {}
    for row in range(plate_rows):
        images[str(row+1)] = {}
        for column in range(plate_columns):
            images[str(row+1)][str(column+1)] = {}

    for image in metadata.findall("./PE:Images/PE:Image",NS):
        row = image.find("./PE:Row",NS).text
        column = image.find("./PE:Col",NS).text
        images[row][column] = {
            "filename": f"{images_path}/{image.find('./PE:URL',NS).text}"
        }

    print(f"[*] Building OME Plate")
    # build companion file
    omePlate = Plate(plate_name, plate_rows, plate_columns)
    print(f"[*] Reading image metadata")
    for row in range(plate_rows):
        for column in range(plate_columns):
            well = omePlate.add_well(row, column)
            i = images[str(row+1)][str(column+1)]
            if i.get("filename") is None or not Path(i["filename"]).is_file():
                continue
            well_metadata = ET.fromstring(tiffcomment(i["filename"]))
            pixel_data = well_metadata.find("./OME:Image/OME:Pixels", NS).attrib

            image_psx = float(pixel_data['PhysicalSizeX']) if 'PhysicalSizeX' in pixel_data else None
            image_psy = float(pixel_data['PhysicalSizeY']) if 'PhysicalSizeY' in pixel_data else None
            image_psz = float(pixel_data['PhysicalSizeZ']) if 'PhysicalSizeZ' in pixel_data else None

            image_name = Path(i['filename']).name
            print(f"- {image_name}", end="")

            image = Image(image_name,
                          sizeX=int(pixel_data['SizeX']),
                          sizeY=int(pixel_data['SizeY']),
                          sizeZ=int(pixel_data['SizeZ']),
                          sizeC=int(pixel_data['SizeC']),
                          sizeT=int(pixel_data['SizeT']),
                          physSizeX=image_psx,
                          physSizeY=image_psy,
                          physSizeZ=image_psz,
                          order=pixel_data['DimensionOrder'],
                          type=pixel_data['Type'])

            channels_data = well_metadata.findall("./**/OME:Channel", NS)
            print(f" - Channels:", end="")
            for channel in channels_data:
                if 'Name' in channel.attrib:
                    image.add_channel(channel.attrib["Name"], channel.attrib["Color"])
                    print(channel.attrib["Name"], end="|")

            tiffs_data = well_metadata.findall("./**/OME:TiffData", NS)
            for t in tiffs_data:
                tiff_filename = t[0].attrib['FileName'] # <UUID FileName="...">
                image.add_tiff(tiff_filename,
                               c=t.attrib['FirstC'],
                               t=t.attrib['FirstT'],
                               z=t.attrib['FirstZ'],
                               ifd=t.attrib['IFD'],
                               planeCount=t.attrib['PlaneCount'])
            well.add_wellsample(0, image)
            print()

    companion_filename = f"{plate_name}.companion.ome"
    print(f"[*] Writing {companion_filename}")
    create_companion(plates=[omePlate], out=companion_filename)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Build OME-XML from Perkin Elmer index.xml output of stitching')
    parser.add_argument('--evaluation_input_data_file', type=str, default="index.xml", required=False,
                        help='Name of the XML file containing plate information')
    parser.add_argument('--images_path', type=str, required=True,
                        help='Path to the images and indedx file')
    args = parser.parse_args()

    print(f"[*] evaluation_input_data_file = {args.evaluation_input_data_file}")
    print(f"[*] images_path = {args.images_path}")

    main(args.evaluation_input_data_file, args.images_path)
