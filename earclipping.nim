import basic2d
import lists
import sets
import hashes
import algorithm

type

    Edge = tuple
        a, b: Vector2d

    Vertex = DoublyLinkedNode[Vector2d]

    Angles = tuple
        convex, reflex: HashSet[Vertex]

    Triangle* = tuple
        a, b, c: Vector2d

    WindingOrder* = enum
        woClockWise, woCounterClockWise

    Polygon* = seq[Vector2d]

proc hash(v: Vertex): Hash =
    result = result !& v.value.x.hash
    result = result !& v.value.y.hash
    result = !$result

proc takeAny[T](s: HashSet[T]): T =
    for item in s:
        return item

proc checkPointToSegment(sA, sB, point: Vector2d): bool =
    if (sA.y < point.y and sB.y >= point.y) or
            (sB.y < point.y and sA.y >= point.y):
        let x = 
            sA.x + 
            (point.y - sA.y) / 
            (sB.y - sA.y) * 
            (sB.x - sA.x)

        if x < point.x:
            return true

proc contains(t: Triangle, v: Vector2d): bool =
    if checkPointToSegment(t.c, t.a, v):
        result = not result
    if checkPointToSegment(t.a, t.b, v):
        result = not result
    if checkPointToSegment(t.b, t.c, v):
        result = not result

proc hasVector(t: Triangle, v: Vector2d): bool =
    v in [t.a, t.b, t.c]

proc hasVector(e: Edge, v: Vector2d): bool =
    v in [e.a, e.b]

proc isEar(v: Vertex, reflex: HashSet[Vertex]): bool =
    let triangle = (v.prev.value, v.value, v.next.value)

    for v2 in reflex:
        if triangle.contains(v2.value) and not triangle.hasVector(v2.value):
            return false

    return true;

proc isConvex(v: Vertex): bool =
    let p = v.prev
    let n = v.next
    
    # Vector magic
    var d1 = v.value - p.value
    d1.normalize # Add `normalized` to stdlib?
    var d2 = n.value - v.value
    d2.normalize
    var n2 = Vector2d(x: -d2.y, y: d2.x)
    return d1.dot(n2) <= 0

proc updateClassification(vertex: Vertex, ears: var HashSet[Vertex], angles: var Angles) =
    if vertex in angles.reflex:
        if vertex.isConvex:
            angles.reflex.excl vertex
            angles.convex.incl vertex

    if vertex in angles.convex:
        let wasEar = vertex in ears
        let isEar = isEar(vertex, angles.reflex)

        if wasEar and not isEar:
            ears.excl vertex

        elif not wasEar and isEar:
            ears.incl vertex

proc classify(vertices: DoublyLinkedRing[Vector2d]): Angles =
    var convex = initSet[Vertex]()
    var reflex = initSet[Vertex]()

    for node in vertices.nodes:
        if node.isConvex:
            convex.incl node
        else:
            reflex.incl node

    return (convex, reflex)

proc initialEars(angles: Angles): HashSet[Vertex] =
    result = initSet[Vertex]()
    for v in angles.convex:
        if isEar(v, angles.reflex):
            result.incl v

proc clipNextEar(triangles: var seq[Triangle], vertices: var DoublyLinkedRing[Vector2d], ears: var HashSet[Vertex], angles: var Angles) =
    let ear = ears.takeAny
    var triangle = (ear.value, ear.next.value, ear.prev.value)
    triangles.add triangle

    vertices.remove ear
    ears.excl ear

    updateClassification(ear.prev, ears, angles);
    updateClassification(ear.next, ears, angles);

proc intersection(vec: Vector2d, edge: Edge): Vector2d =
    #if edge.a.x > vec.x or edge.b.x > vec.x
    let k = (edge.a.y - edge.b.y)

iterator edges(polygon: Polygon): Edge =
    yield (polygon[^1], polygon[0])

    for idx in 0 ..< high(polygon):
        let a = polygon[idx]
        let b = polygon[idx + 1]
        yield (a, b)

proc resolveHole(polygon: Polygon, hole: Polygon, angles: Angles): Polygon =
    # Converts a polygon with a hole to a simple polygon without a hole.

    # Find the rightmost vector in the hole
    var xMax = -Inf
    var holeVector : Vector2d
    for v in hole:
        if v.x > xMax:
            xMax = v.x
            holeVector = v
    
    var intersectedEdge : Edge
    var intersection = Vector2d(x: Inf, y: Inf)
   
    for edge in polygon.edges:
        let v = intersection(holeVector, edge)
        if v.x < intersection.x:
            intersection = v
            intersectedEdge = edge
    
    let rightMostOfIntersected = 
        if intersectedEdge.a.x > intersectedEdge.b.x:
            intersectedEdge.a
        else:
            intersectedEdge.b

    if intersectedEdge.hasVector intersection:
        discard # Resolve

    let triangle = (holeVector, intersection, rightMostOfIntersected)
    var inside = newSeq[Vector2d]()

    for v in angles.reflex:
        if v.value != rightMostOfIntersected:
            if triangle.contains v.value:
                inside.add v.value

    if inside.len == 0:
        discard # Resolve

    var minAngle = 0f
    var vertex = intersection - holeVector
    var minAngleVector : Vector2d

    for v in inside:
        let angle = angleCW(vertex, v - holeVector)
        if angle < minAngle:
            minAngle = angle
            minAngleVector = v

    # Resolve

proc triangulate*(polygon: Polygon, holes: openArray[Polygon]): seq[Triangle] =
    result = newSeq[Triangle]()

    var vertices = initDoublyLinkedRing[Vector2d]()

    for v in polygon:
        vertices.append v

    var angles = vertices.classify
    var ears = angles.initialEars
    var len = polygon.len

    while len > 3 and ears.len > 0:
        clipNextEar result, vertices, ears, angles
        len.dec

    assert len == 3 # Always true if polygon is a simple polygon

    var head = vertices.head
    result.add((head.next.value, head.next.next.value, head.value))

proc triangulate*(polygon: Polygon): seq[Triangle] =
    triangulate(polygon, [])

proc windingOrder*(polygon: Polygon): WindingOrder =
    var nClockWise = 0
    var nCounterClockwise = 0

    proc count(v1, v2, v3: Vector2d) =
        let e1 = v1 - v2
        let e2 = v3 - v2

        let val = e1.x * e2.y - e1.y * e2.x

        if   val < 0: nClockWise.inc
        elif val > 0: nCounterClockwise.inc

    for i in 0 .. polygon.high:
        count polygon[i], polygon[(i + 1) mod polygon.len], polygon[(i + 2) mod polygon.len]

    return 
        if nClockWise > nCounterClockwise:
            woClockwise
        else:
            woCounterClockwise

proc enforceWindingOrder*(polygon: Polygon, order: WindingOrder): Polygon =
    if polygon.windingOrder == order:
        polygon
    else:
        polygon.reversed