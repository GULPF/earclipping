# TODO: Enforce winding order of returned triangles.
# TODO: Enforce winding order of input.
# TODO: Add proc for converting winding order.

import unittest
import basic2d
import earclipping
import sequtils

type 
    IntPoint = tuple
        x, y: int

proc polygon(p: openArray[IntPoint]): Polygon =
    return @p.mapIt(Vector2d(x: (float)it.x, y: (float)it.y)).Polygon

proc triangles(ts: seq[tuple[a: IntPoint, b: IntPoint, c: IntPoint]]): seq[Triangle] =
    return @ts.mapIt((
        (Vector2d(x: (float)it.a.x, y: (float)it.a.y)),
        (Vector2d(x: (float)it.b.x, y: (float)it.b.y)), 
        (Vector2d(x: (float)it.c.x, y: (float)it.c.y))).Triangle)

# Polygons are considered equal if they contains the same points in the same order,
# ignoring which point is the first.
proc `==`(p1, p2: Polygon): bool =
    if p1.len != p2.len:
        return false

    var idx1 = 0
    var idx2 = 0

    var v1 = p1[idx1]
    while p2[idx2] != v1 and idx2 < p2.len:
        idx2.inc

    if idx2 == p2.len:
        return false

    var nChecked = 0
    while nChecked < p1.len:
        if p1[idx1] != p2[idx2]:
            return false
        idx1 = (idx1 + 1) mod p1.len
        idx2 = (idx2 + 1) mod p2.len
        nChecked.inc
    
    return true

test "Rectangle":
    let poly = [(0, 0), (1, 0), (1, 1), (0, 1)].polygon
    let triangles = poly.triangulate
    let expected = @[((0, 0), (1, 0), (0, 1)), ((1, 0), (1, 1), (0, 1))].triangles
    check(triangles == expected)

test "winding order":
    let ccw = [(0, 0), (0, 1), (1, 1), (1, 0)].polygon
    let cw = [(0, 0), (1, 0), (1, 1), (0, 1)].polygon
    check ccw.windingOrder == woCounterClockWise
    check cw.windingOrder == woClockWise
    check ccw.enforceWindingOrder(woClockWise) == cw
    check cw.enforceWindingOrder(woCounterClockWise) == ccw
    check cw.enforceWindingOrder(woClockWise) == cw
    check ccw.enforceWindingOrder(woCounterClockWise) == ccw