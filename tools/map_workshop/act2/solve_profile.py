"""Bounded native profile experiment; source graph and planar coordinates stay intact."""
import argparse
import json
from pathlib import Path
import numpy as np
from scipy.optimize import linprog
from scipy.sparse import coo_matrix
from scipy.spatial import cKDTree


def solve(source_path, output_path, scale=1.0, footprint_radius=0.0, library_level=None):
    source = json.loads(Path(source_path).read_text())
    routes = source['routes']
    positions, references, route_indices, node_indices = [], [], {}, {}
    bridge_nodes = {e[k] for e in routes.values() if e['raised'] for k in ('from', 'to')}
    for key, edge in routes.items():
        indices = []
        for j, p in enumerate(edge['points']):
            node = edge['from'] if j == 0 else edge['to'] if j == len(edge['points']) - 1 else None
            if node is not None and node in node_indices:
                index = node_indices[node]
            else:
                index = len(positions)
                positions.append([p[0] * scale, p[2] * scale])
                references.append(p[1])
                if node is not None:
                    node_indices[node] = index
            indices.append(index)
        route_indices[key] = indices
    positions = np.array(positions)
    n = len(positions)
    rows, cols, values, limits = [], [], [], []
    erows, ecols, evals, targets = [], [], [], []

    def inequality(entries, limit):
        row = len(limits)
        for column, value in entries:
            rows.append(row); cols.append(column); values.append(value)
        limits.append(limit)

    def equality(a, b):
        row = len(targets)
        erows.extend([row, row]); ecols.extend([a, b]); evals.extend([1, -1]); targets.append(0)

    for i, reference in enumerate(references):
        inequality([(i, 1), (n+i, -1)], reference)
        inequality([(i, -1), (n+i, -1)], -reference)
    for key, edge in routes.items():
        ids = route_indices[key]
        steps = np.linalg.norm(np.diff(positions[ids], axis=0), axis=1)
        stations = np.r_[0, np.cumsum(steps)]
        for a, b, length in zip(ids, ids[1:], steps):
            inequality([(a, 1), (b, -1)], .44*length)
            inequality([(b, 1), (a, -1)], .44*length)
        for j, index in enumerate(ids):
            if edge['from'] in bridge_nodes and 0 < stations[j] < 1.55:
                equality(index, ids[0])
            if edge['to'] in bridge_nodes and 0 < stations[-1]-stations[j] < 1.55:
                equality(index, ids[-1])
    # Freeze the complete overlapping footprints of incident approaches, not
    # merely their first centreline metre. This makes their shared deck planar.
    footprint_equalities = 0
    items = list(routes.items()) if footprint_radius > 0 else []
    for ordinal, (a_key, a_edge) in enumerate(items):
        ai = route_indices[a_key]
        for b_key, b_edge in items[ordinal+1:]:
            common = {a_edge['from'], a_edge['to']} & {b_edge['from'], b_edge['to']}
            if not common:
                continue
            bi = route_indices[b_key]
            tree = cKDTree(positions[bi])
            for j, neighbours in enumerate(tree.query_ball_point(positions[ai], footprint_radius)):
                for k in neighbours:
                    equality(ai[j], bi[k])
                    footprint_equalities += 1
    turn_equalities = 0
    if footprint_radius > 0:
        for key, edge in routes.items():
            ids = route_indices[key]
            xy = positions[ids]
            stations = np.r_[0, np.cumsum(np.linalg.norm(np.diff(xy, axis=0), axis=1))]
            for j, k in cKDTree(xy).query_pairs(footprint_radius):
                distance = np.linalg.norm(xy[j]-xy[k])
                arc = abs(stations[k]-stations[j])
                if arc > 1.0 and arc > distance*1.15:
                    equality(ids[j], ids[k])
                    turn_equalities += 1
    crossing_pairs = []
    for upper_key, upper in routes.items():
        if not upper['raised']:
            continue
        ui = route_indices[upper_key]
        up = positions[ui]
        for lower_key, lower in routes.items():
            if lower['raised'] or {upper['from'], upper['to']} & {lower['from'], lower['to']}:
                continue
            li = route_indices[lower_key]
            low = positions[li]
            intersects = False
            # Cross products in two dimensions, without deprecated np.cross(2D).
            def cross(a, b):
                return a[..., 0]*b[..., 1]-a[..., 1]*b[..., 0]
            for a, b in zip(up, up[1:]):
                ab = b-a
                cd = np.diff(low, axis=0)
                denom = cross(ab, cd)
                safe = np.abs(denom) > 1e-9
                t = np.divide(cross(low[:-1]-a, cd), denom, out=np.zeros_like(denom), where=safe)
                u = np.divide(cross(low[:-1]-a, ab), denom, out=np.zeros_like(denom), where=safe)
                if np.any(safe & (t > 0) & (t < 1) & (u > 0) & (u < 1)):
                    intersects = True
                    break
            if not intersects:
                continue
            crossing_pairs.append([upper_key, lower_key])
            tree = cKDTree(low)
            for j, neighbours in enumerate(tree.query_ball_point(up, 2.0)):
                for k in neighbours:
                    inequality([(li[k], 1), (ui[j], -1)], -2.8)
    bounds = [(1.55, 9.0)]*n+[(0, None)]*n
    if library_level is not None:
        bounds[node_indices["2,0"]] = (library_level, library_level)
    cost = np.r_[np.zeros(n), np.ones(n)]
    result = linprog(cost, A_ub=coo_matrix((values, (rows, cols)), shape=(len(limits), 2*n)).tocsr(), b_ub=limits,
                     A_eq=coo_matrix((evals, (erows, ecols)), shape=(len(targets), 2*n)).tocsr(), b_eq=targets,
                     bounds=bounds, method='highs', options={'time_limit': 60})
    report = {'success': bool(result.success), 'message': result.message, 'source_digest': source['source_digest'],
              'library_level': library_level, 'scale': scale, 'vertices': n, 'constraints': len(limits), 'landing_equalities': len(targets),
              'turn_equalities': turn_equalities, 'footprint_radius': footprint_radius, 'footprint_equalities': footprint_equalities, 'crossing_pairs': crossing_pairs, 'grade_limit': .44, 'landing_run': 1.55, 'crossing_separation': 2.8}
    if result.success:
        report['maximum_constraint_violation'] = float(max(0, -min(result.ineqlin.residual)))
        report['routes'] = {key: [[float(positions[i, 0]), float(result.x[i]), float(positions[i, 1])] for i in ids]
                            for key, ids in route_indices.items()}
    Path(output_path).write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k != 'routes'}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source')
    parser.add_argument('output')
    parser.add_argument('--scale', type=float, default=1.0)
    parser.add_argument('--footprint-radius', type=float, default=0.0)
    parser.add_argument('--library-level', type=float)
    args = parser.parse_args()
    solve(args.source, args.output, args.scale, args.footprint_radius, args.library_level)
