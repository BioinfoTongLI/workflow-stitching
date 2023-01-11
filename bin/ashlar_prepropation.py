import copy
import logging
import os
import shutil
import subprocess
from pathlib import Path
from subprocess import Popen
from typing import List, Union

import dask
import tifffile
from ISS_processing.preprocessing import ashlar_wrapper
from aicsimageio.readers import OmeTiffReader
from dask.array import stack as dstack
from dask_image.imread import imread
from tqdm import tqdm

from index_file_cropping import read_xml, crop, save_xml


# NOT FULLY TESTED
def grab_subsample(
    source_images_folders: List[Union[Path, str]],
    subsample_folder: Union[Path, str],
    x: int = 80000,
    y: int = 65000 - 30000,
    d: int = 10000,
) -> None:

    """source_images_folder should be list of folders for copying

    Takes subsample of the whole image"""

    folders = sorted(source_images_folders)
    subsample_folder = Path(subsample_folder)

    n_cyc = len(folders)
    experiment_prefix = [
        f"cyc{i+1:02}" for i in range(n_cyc)
    ]  # numbers of cycles is less than 100

    # TODO parallelisation through threads
    for index, folder in enumerate(folders):
        logging.debug(f"Cycle number {index}")

        folder = Path(folder) / "Images"

        doc = read_xml(folder / "Index.xml")
        cropped_df = crop(
            doc, x=x, y=y, d=d, draw=False
        )  # doc is affected, crop is not a pure function

        output_folder = subsample_folder / f"aw_{experiment_prefix[index]}"
        os.makedirs(output_folder, exist_ok=True)

        for file in tqdm(cropped_df.url.values):
            shutil.copyfile(folder / file, output_folder / file)

        save_xml(doc, output_folder / "Index.xml")


# NOT FULLY TESTED
def assemble_ome_tif(
    subsample_folder: Union[Path, str],
    ometif_folder: Union[Path, str],
    bfconvert_path: Union[
        Path, str
    ] = "/nfs/casm/team299ly/al15/tools/bftools/bfconvert",
) -> List[int]:
    """Launches bf-converter to get ome.tif from raw images"""

    cyc_folders = sorted(os.listdir(subsample_folder))

    processes = []
    for folder in cyc_folders:
        folder = Path(subsample_folder) / folder
        s = folder / "Index.xml"
        t = Path(ometif_folder) / f"{folder}_subsampled.ome.tiff"
        processes.append(Popen(f"{bfconvert_path} {s} {t}".split()))

    exit_codes = [p.wait() for p in processes]
    return exit_codes


def make_mip(
    ometif_folder: Union[Path, str],
    mipped_ometif_folder: Union[Path, str],
    tmp_folder: Union[Path, str],  # FIXME
    fix_optics=False,
) -> None:
    """Takes ome.tif file and calculates maximum intensity project after that saves to ome.tif"""

    ometif_folder = Path(ometif_folder)
    tmp_folder = Path(tmp_folder)

    cyc_files = sorted(os.listdir(ometif_folder))

    # Add parallelisation
    for index, file in tqdm(enumerate(cyc_files), total=len(cyc_files)):
        ome = OmeTiffReader(ometif_folder / file)

        meta = copy.deepcopy(ome.metadata)

        print("Reading dask array")
        dask_dat = ome.get_dask_stack()
        print("Calculating mip")
        darr = dstack(dask_dat).max(3)[:, 0, :, :, :]

        if fix_optics:  # WORKS BUT NEED TO BE TESTED
            # save to the disk
            dapi_folder = tmp_folder / f"dapi_{index}"
            input_folder = tmp_folder / f"input_tiffs_{index}"
            output_folder = tmp_folder / f"output_tiffs_{index}"

            # Save dapi channel
            os.makedirs(dapi_folder, exist_ok=True)
            print("Saving to tmp")
            for i in range(darr.shape[0]):
                with tifffile.TiffWriter(dapi_folder / f"{i}.tiff") as tif:
                    tif.write(darr[i, 0, :, :].astype("uint16"))

            base_command = f"conda run -n ds python basic_shading_correction.py"
            # train

            command = f"{base_command} --estimate_darkfield --extension tiff {dapi_folder} {dapi_folder}"
            result = subprocess.run(command, shell=True, capture_output=True)
            print(result)

            # Save all images
            os.makedirs(input_folder, exist_ok=True)
            for i in range(darr.shape[0]):
                for j in range(darr.shape[1]):
                    with tifffile.TiffWriter(input_folder / f"{i}_{j}.tiff") as tif:
                        tif.write(darr[i, j, :, :].astype("uint16"))

            # predict
            command = f"{base_command}\
                        --use_flatfield {dapi_folder / 'flatfield.tif'} \
                        --use_darkfield {dapi_folder / 'darkfield.tif'} \
                        --apply_correction --extension tiff\
                        {input_folder} {output_folder}"

            os.makedirs(output_folder, exist_ok=True)

            result = subprocess.run(command, shell=True, capture_output=True)
            print(result)

            images = []
            for i in range(darr.shape[0]):
                images.append(
                    dask.array.concatenate(
                        [
                            imread(output_folder / f"{i}_{j}.tiff")
                            for j in range(darr.shape[1])
                        ]
                    )
                )

            darr = dask.array.concatenate([i[None, :, :, :] for i in images])
            # read it again

        n_tiles = len(meta.images)
        pixel_size = meta.images[0].pixels.physical_size_x
        positions = [
            (x.pixels.planes[0].position_x * 1e6, x.pixels.planes[0].position_y * 1e6)
            for x in meta.images
        ]
        num_channels = darr.shape[1]

        with tifffile.TiffWriter(
            mipped_ometif_folder / f"{file[:-9]}.ome.tiff", bigtiff=True
        ) as tif:
            for tile_index in tqdm(range(n_tiles)):
                position = positions[tile_index]
                stacked = darr[tile_index, :, :, :]
                metadata = {
                    "Pixels": {
                        "PhysicalSizeX": pixel_size,
                        "PhysicalSizeXUnit": "µm",
                        "PhysicalSizeY": pixel_size,
                        "PhysicalSizeYUnit": "µm",
                    },
                    "Plane": {
                        "PositionX": [position[0]] * num_channels,
                        "PositionY": [position[1]] * num_channels,
                    },
                }
                tif.write(stacked.astype("uint16"), metadata=metadata)


def launch_ashlar(ometif_folder, stiched_folder):
    ometif_folder = Path(ometif_folder)
    OME_tiffs = sorted(
        [str(ometif_folder / filename) for filename in os.listdir(ometif_folder)]
    )
    ashlar_wrapper(
        files=OME_tiffs, output=stiched_folder, align_channel=0, flip_y=False
    )
