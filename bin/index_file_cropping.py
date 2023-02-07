#! /usr/bin/env python
# -*- coding: utf-8 -*-
# vim:fenc=utf-8import os

import pandas as pd
import numpy as np

# import matplotlib.pyplot as plt
import sys
from xml.dom import minidom
from io import StringIO

import fire
import logging


def read_xml(path):
    return minidom.parse(StringIO("".join([i.strip() for i in open(path).readlines()])))


def save_xml(doc, path):
    with open(path, "w") as f:
        f.write(doc.toprettyxml())


def get_xyz(doc):
    xs = doc.getElementsByTagName("PositionX")
    ys = doc.getElementsByTagName("PositionY")
    zs = doc.getElementsByTagName("PositionZ")

    return xs, ys, zs


def get_resolution_size(doc):
    """
    '      <Entry ChannelID="2">\n',
    '        <ChannelName>Cy5</ChannelName>\n',
    '        <ImageResolutionX Unit="m">1.4834406623735051E-07</ImageResolutionX>\n',
    '        <ImageResolutionY Unit="m">1.4834406623735051E-07</ImageResolutionY>\n',
    '        <ImageSizeX>2160</ImageSizeX>\n',
    '        <ImageSizeY>2160</ImageSizeY>\n',
    """

    resolution = float(doc.getElementsByTagName("ImageResolutionX")[0].firstChild.data)
    size = float(doc.getElementsByTagName("ImageSizeX")[0].firstChild.data)

    return resolution, size


def get_array(array):
    return np.array([float(array[i].firstChild.data) for i in range(len(array))])


def get_unique(array):
    array = np.unique(
        np.array([float(array[i].firstChild.data) for i in range(len(array))])
    )
    return len(array), array


def get_min(doc):
    xs, ys, zs = get_xyz(doc)
    resolution, _ = get_resolution_size(doc)

    minx = np.min(get_array(xs) / resolution)
    miny = np.min(get_array(ys) / resolution)

    return minx, miny


def draw(doc, skip=1, x=None, y=None, d=10000, minx=None, miny=None):
    plt.figure(figsize=(14, 10))
    resolution, size = get_resolution_size(doc)
    xs, ys, zs = get_xyz(doc)

    if minx is None:
        minx = np.min(get_array(xs) / resolution)

    if miny is None:
        miny = np.min(get_array(ys) / resolution)

    # maxx = np.max(get_array(xs) / resolution)
    # maxy = np.max(get_array(ys) / resolution)

    plt.scatter(
        get_array(xs) / resolution - minx, get_array(ys) / resolution - miny, s=2
    )
    plt.scatter(
        get_array(xs) / resolution - minx + size,
        get_array(ys) / resolution - miny + size,
        s=1,
    )

    plt.plot(
        np.array(
            [
                get_array(xs) / resolution - minx,
                get_array(xs) / resolution - minx + size,
                get_array(xs) / resolution - minx + size,
                get_array(xs) / resolution - minx,
                get_array(xs) / resolution - minx,
            ]
        )
        .T[:: 5 * skip]
        .T,
        np.array(
            [
                get_array(ys) / resolution - miny,
                get_array(ys) / resolution - miny,
                get_array(ys) / resolution - miny + size,
                get_array(ys) / resolution - miny + size,
                get_array(ys) / resolution - miny,
            ]
        )
        .T[:: 5 * skip]
        .T,
        linewidth=0.5,
    )

    if x is not None and y is not None:
        plt.plot(
            [x, x + d, x + d, x, x], [y, y, y + d, y + d, y], color="black", linewidth=2
        )

    plt.axis("equal")


def is_inside_square(
    coord, minX, minY, resolution, size, square=(80000, 65000 - 30000), d=10000
):
    minx, miny = square

    x, y = coord["x"] / resolution - minX, coord["y"] / resolution - minY
    if (minx < x < (minx + d) or minx < x + size < (minx + d)) and (
        miny < y < miny + d or miny < y + size < miny + d
    ):
        return True

    return False


def crop(doc, x=80000, y=65000 - 30000, d=10000, draw=False, minx=None, miny=None):
    coords = [
        {
            "z": float(i.getElementsByTagName("PositionZ")[0].firstChild.data),
            "y": float(i.getElementsByTagName("PositionY")[0].firstChild.data),
            "x": float(i.getElementsByTagName("PositionX")[0].firstChild.data),
            "id": i.getElementsByTagName("id")[0].firstChild.data,
            "url": i.getElementsByTagName("URL")[0].firstChild.data,
        }
        for i in doc.getElementsByTagName("Images")[0].childNodes
    ]

    resolution, size = get_resolution_size(doc)
    if minx is None or miny is None:
        minx, miny = get_min(doc)

    intersect = [
        i
        for i in coords
        if is_inside_square(i, minx, miny, resolution, size, square=(x, y), d=d)
    ]
    intersect_df = pd.DataFrame(intersect)
    print(intersect_df)
    intersect_id_set = set(intersect_df["id"].tolist())

    if draw:
        plt.plot([x, x + d, x + d, x, x], [y, y, y + d, y + d, y], color="black")

        plt.plot(
            [
                intersect_df["x"] / resolution - minx,
                intersect_df["x"] / resolution - minx + size,
                intersect_df["x"] / resolution - minx + size,
                intersect_df["x"] / resolution - minx,
                intersect_df["x"] / resolution - minx,
            ],
            [
                intersect_df["y"] / resolution - miny,
                intersect_df["y"] / resolution - miny,
                intersect_df["y"] / resolution - miny + size,
                intersect_df["y"] / resolution - miny + size,
                intersect_df["y"] / resolution - miny,
            ],
        )
        plt.axis("equal")

    ### Deleting from wells
    print(
        "Wells before",
        len(doc.getElementsByTagName("Wells")[0].getElementsByTagName("Image")),
    )
    for element in doc.firstChild.getElementsByTagName("Wells")[0].getElementsByTagName(
        "Image"
    ):
        if element.getAttribute("id") not in intersect_id_set:
            element.parentNode.removeChild(element)
    print(
        "Wells after",
        len(doc.getElementsByTagName("Wells")[0].getElementsByTagName("Image")),
    )

    ### Deleting from images
    print(
        "Images before",
        len(doc.getElementsByTagName("Images")[0].getElementsByTagName("Image")),
    )
    for element in doc.getElementsByTagName("Images")[0].getElementsByTagName("Image"):
        if (
            element.getElementsByTagName("id")[0].firstChild.data
            not in intersect_id_set
        ):
            element.parentNode.removeChild(element)
    print(
        "Images after",
        len(doc.getElementsByTagName("Images")[0].getElementsByTagName("Image")),
    )

    return intersect_df


def main(index_file):
    doc = read_xml(index_file)
    cropped_df = crop(doc, x=0, y=0, d=100000, draw=False)
    logging.debug(cropped_df)
    save_xml(doc, "test.index.xml")


if __name__ == "__main__":
    fire.Fire(main)
