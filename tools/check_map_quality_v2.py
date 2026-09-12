#!/usr/bin/env python3
"""Fail-closed validation for docs/map/map-quality-v2.json."""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import sys
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parent.parent
DEFAULT = REPO / "docs" / "map" / "map-quality-v2.json"

ROOT = {
    "schema_version", "contract_version", "registry_id", "evaluation_order", "units",
    "epsilon", "hard_empty_policy", "soft_not_applicable_policy", "profiles",
    "calibration", "geometry", "hard", "soft", "hierarchy", "renderer", "zones",
    "provisional_ids", "review_items",
}
HARD_KEYS = {"id", "measure", "unit", "op", "limit", "scope", "class", "provisional", "owner"}
SOFT_KEYS = {"id", "measure", "unit", "direction", "best", "worst", "aggregation",
             "weight", "owner", "rationale", "empty_policy"}
UNITS = {
    "world": "m", "screen": "px", "screen_area": "px2", "angle": "deg",
    "angle_per_edge": "deg_per_edge", "count": "count", "ratio": "ratio",
}
HARD_UNITS, SOFT_UNITS = {"px", "px2", "m", "count"}, {"ratio", "deg_per_edge", "px", "m"}
HARD_IDS = {
    "node_ink_clearance_px", "node_touch_target_min_px", "node_touch_overlap_area_px2",
    "node_touch_scenery_silhouette_overlap_area_px2",
    "node_touch_hero_silhouette_overlap_area_px2", "node_node_ink_overlap_area_px2",
    "node_scenery_silhouette_overlap_area_px2",
    "node_hero_silhouette_overlap_area_px2", "edge_scenery_corridor_penetration_m",
    "edge_nonendpoint_node_penetration_m", "unrelated_edge_intersection_count",
    "branch_fanout_separation_px", "row_lane_envelope_excess_m",
    "journey_order_reversal_count", "vigil_protected_zone_intrusion_count",
    "terminus_protected_zone_intrusion_count", "focused_node_safe_frame_margin_px",
    "deterministic_identity_mismatch_count",
}
SOFT_IDS = {
    "route_length_ratio", "bend_angle_deg_per_edge", "branch_separation_margin_px",
    "route_state_exposure_ratio", "landmark_framing_margin_px", "zone_density_error_ratio",
    "negative_space_error_ratio", "asset_family_diversity_ratio",
    "asset_repetition_distance_m", "stamping_symmetry_ratio", "node_displacement_rms_m",
    "camera_profile_consistency_ratio",
}
ZERO_IDS = {
    "node_touch_overlap_area_px2", "node_touch_scenery_silhouette_overlap_area_px2",
    "node_touch_hero_silhouette_overlap_area_px2", "node_node_ink_overlap_area_px2",
    "node_scenery_silhouette_overlap_area_px2", "node_hero_silhouette_overlap_area_px2",
    "edge_scenery_corridor_penetration_m", "edge_nonendpoint_node_penetration_m",
    "unrelated_edge_intersection_count", "row_lane_envelope_excess_m",
    "journey_order_reversal_count", "vigil_protected_zone_intrusion_count",
    "terminus_protected_zone_intrusion_count", "deterministic_identity_mismatch_count",
}
POSITIVE_FLOOR_IDS = {
    "node_ink_clearance_px", "branch_fanout_separation_px", "focused_node_safe_frame_margin_px",
}
REQUIRED_MINIMUM_IDS = {
    "node_ink_clearance_px", "node_touch_target_min_px", "focused_node_safe_frame_margin_px",
}
OPTIONAL_MINIMUM_IDS = {"branch_fanout_separation_px"}
HARD_OWNERS = {
    "node_ink_clearance_px": 466, "node_touch_target_min_px": 466,
    "node_touch_overlap_area_px2": 466,
    "node_touch_scenery_silhouette_overlap_area_px2": 466,
    "node_touch_hero_silhouette_overlap_area_px2": 466,
    "node_node_ink_overlap_area_px2": 466,
    "node_scenery_silhouette_overlap_area_px2": 466,
    "node_hero_silhouette_overlap_area_px2": 466,
    "edge_scenery_corridor_penetration_m": 468,
    "edge_nonendpoint_node_penetration_m": 466,
    "unrelated_edge_intersection_count": 469, "branch_fanout_separation_px": 469,
    "row_lane_envelope_excess_m": 467, "journey_order_reversal_count": 467,
    "vigil_protected_zone_intrusion_count": 470,
    "terminus_protected_zone_intrusion_count": 470,
    "focused_node_safe_frame_margin_px": 466,
    "deterministic_identity_mismatch_count": 464,
}
SOFT_OWNERS = {
    "route_length_ratio": 468, "bend_angle_deg_per_edge": 468,
    "branch_separation_margin_px": 469, "route_state_exposure_ratio": 466,
    "landmark_framing_margin_px": 470, "zone_density_error_ratio": 470,
    "negative_space_error_ratio": 470, "asset_family_diversity_ratio": 470,
    "asset_repetition_distance_m": 470, "stamping_symmetry_ratio": 470,
    "node_displacement_rms_m": 471, "camera_profile_consistency_ratio": 466,
}
SOFT_EMPTY_POLICIES = {
    "route_length_ratio":
        "no_edges_is_not_applicable;nonpositive_direct_distance_with_edges_is_evidence_error",
    "bend_angle_deg_per_edge": "no_routed_edges_is_not_applicable",
    "branch_separation_margin_px": "no_decision_branches_is_not_applicable",
    "route_state_exposure_ratio":
        "no_routed_edges_is_not_applicable;nonpositive_total_projected_length_with_edges_is_evidence_error",
    "landmark_framing_margin_px": "no_governed_landmarks_is_evidence_error",
    "zone_density_error_ratio": "exclude_zero_legal_area_zones;all_excluded_is_evidence_error",
    "negative_space_error_ratio":
        "exclude_zero_area_reservations;all_excluded_is_evidence_error",
    "asset_family_diversity_ratio":
        "zero_available_families_is_evidence_error;zero_placements_raw_zero",
    "asset_repetition_distance_m": "fewer_than_two_same_family_instances_raw_best",
    "stamping_symmetry_ratio": "zero_ordinary_placements_raw_zero",
    "node_displacement_rms_m": "no_nodes_is_evidence_error",
    "camera_profile_consistency_ratio":
        "fewer_than_two_profiles_is_evidence_error;zero_max_subscore_raw_one",
}
CLASSES = {"shipping_touch_waystone", "stage_zoom_geometry", "provisional_owner_review",
           "immutable_zero_tolerance"}
HIERARCHY = ["regional_world_and_landmark", "permanent_physical_road",
             "narrow_depth_tested_waylight", "waystones_and_interaction", "chrome"]
RENDERER = {"physical_road_readable_without_state_colour": 472,
            "whole_road_state_recolour_forbidden": 475,
            "route_state_2d_overlay_forbidden": 475,
            "route_state_depth_test_required": 473}
ZONES = {"hero", "foreground-frame", "road-bank", "midground", "vista"}


class ContractError(ValueError):
    pass


def need(ok: bool, message: str) -> None:
    if not ok:
        raise ContractError(message)


def obj(value: Any, path: str) -> dict[str, Any]:
    need(isinstance(value, dict), f"{path}: expected object")
    return value


def arr(value: Any, path: str) -> list[Any]:
    need(isinstance(value, list), f"{path}: expected array")
    return value


def keys(value: dict[str, Any], expected: set[str], path: str) -> None:
    need(not (set(value) - expected), f"{path}: unknown fields {sorted(set(value) - expected)}")
    need(not (expected - set(value)), f"{path}: missing fields {sorted(expected - set(value))}")


def num(value: Any, path: str) -> float:
    need(isinstance(value, (int, float)) and not isinstance(value, bool), f"{path}: expected number")
    out = float(value)
    need(math.isfinite(out), f"{path}: expected finite number")
    return out


def integer(value: Any, path: str) -> int:
    need(isinstance(value, int) and not isinstance(value, bool), f"{path}: expected integer")
    return value


def text(value: Any, path: str) -> str:
    need(isinstance(value, str) and value.strip() != "", f"{path}: expected non-empty string")
    return value


def string_set(value: Any, path: str) -> set[str]:
    rows = arr(value, path)
    need(all(isinstance(item, str) and item.strip() for item in rows),
         f"{path}: expected non-empty strings")
    need(len(rows) == len(set(rows)), f"{path}: duplicate value")
    return set(rows)


def indexed(rows: Any, path: str, expected: set[str]) -> dict[str, dict[str, Any]]:
    out: dict[str, dict[str, Any]] = {}
    for index, raw in enumerate(arr(rows, path)):
        row = obj(raw, f"{path}[{index}]")
        item_id = text(row.get("id"), f"{path}[{index}].id")
        need(item_id not in out, f"{path}: duplicate metric id {item_id!r}")
        out[item_id] = row
    need(not (set(out) - expected), f"{path}: unknown metric IDs {sorted(set(out) - expected)}")
    need(not (expected - set(out)), f"{path}: missing metric IDs {sorted(expected - set(out))}")
    return out


def validate_profiles(root: dict[str, Any]) -> None:
    units = obj(root["units"], "units")
    need(units == UNITS, "units: governed vocabulary drifted")
    need(HARD_UNITS | SOFT_UNITS <= set(units.values()), "units: metric vocabulary is incomplete")
    epsilon = obj(root["epsilon"], "epsilon")
    keys(epsilon, {"world_m", "screen_px", "ratio"}, "epsilon")
    need(0 < num(epsilon["world_m"], "epsilon.world_m") <= 0.001, "epsilon.world_m: too large")
    need(0 < num(epsilon["screen_px"], "epsilon.screen_px") <= 0.25, "epsilon.screen_px: too large")
    need(0 < num(epsilon["ratio"], "epsilon.ratio") <= 0.000001, "epsilon.ratio: too large")

    profiles = obj(root["profiles"], "profiles")
    keys(profiles, {"shapes", "zoom_stops_m", "tilt_deg", "height_m", "poses", "flex_cap", "class"},
         "profiles")
    need(profiles["shapes"] == {"pad-landscape": [1180, 820],
                                "desktop-landscape": [1458, 820],
                                "phone-landscape": [844, 390]},
         "profiles.shapes: shipping set drifted")
    need(profiles["zoom_stops_m"] == [12.0, 16.0, 20.0, 28.0],
         "profiles.zoom_stops_m: drifted")
    need(num(profiles["tilt_deg"], "profiles.tilt_deg") == -40.0,
         "profiles.tilt_deg: drifted")
    need(num(profiles["height_m"], "profiles.height_m") == 18.0,
         "profiles.height_m: drifted")
    need(profiles["poses"] == ["opening", "leading_each_occupied_row", "pan_bounds", "pan_corners"],
         "profiles.poses: governed set drifted")
    need(num(profiles["flex_cap"], "profiles.flex_cap") == 0.12,
         "profiles.flex_cap: drifted")
    need(profiles["class"] == "stage_zoom_geometry",
         "profiles.class: expected stage_zoom_geometry")


def validate_empty_policies(root: dict[str, Any]) -> None:
    policy = obj(root["hard_empty_policy"], "hard_empty_policy")
    keys(policy, {"empty_maximum_or_count", "optional_minimum_ids", "empty_optional_minimum",
                  "required_minimum_ids", "missing_required_entity_or_profile",
                  "deterministic_replay_minimum_samples"}, "hard_empty_policy")
    need(policy["empty_maximum_or_count"] == "emit_zero",
         "hard_empty_policy.empty_maximum_or_count: expected emit_zero")
    need(policy["empty_optional_minimum"] == "emit_not_applicable_and_pass",
         "hard_empty_policy.empty_optional_minimum: unexpected policy")
    need(policy["missing_required_entity_or_profile"] == "evidence_error",
         "hard_empty_policy.missing_required_entity_or_profile: expected evidence_error")
    need(string_set(policy["optional_minimum_ids"], "hard_empty_policy.optional_minimum_ids")
         == OPTIONAL_MINIMUM_IDS, "hard_empty_policy.optional_minimum_ids: governed set drifted")
    need(string_set(policy["required_minimum_ids"], "hard_empty_policy.required_minimum_ids")
         == REQUIRED_MINIMUM_IDS, "hard_empty_policy.required_minimum_ids: governed set drifted")
    need(integer(policy["deterministic_replay_minimum_samples"],
                 "hard_empty_policy.deterministic_replay_minimum_samples") == 2,
         "hard_empty_policy.deterministic_replay_minimum_samples: expected 2")
    need(root["soft_not_applicable_policy"]
         == "exclude_component_and_renormalise_remaining_initial_weights",
         "soft_not_applicable_policy: governed policy drifted")


def validate_calibration(root: dict[str, Any]) -> None:
    calibration = obj(root["calibration"], "calibration")
    keys(calibration, {"classes", "shipping_touch_waystone", "stage_zoom_geometry", "baseline",
                       "status", "release_review_required"}, "calibration")
    need(string_set(calibration["classes"], "calibration.classes") == CLASSES,
         "calibration.classes: unknown or missing class")
    shipping = obj(calibration["shipping_touch_waystone"], "calibration.shipping_touch_waystone")
    keys(shipping, {"ink_radius_px", "phone_touch_floor_px", "default_layout_scale",
                    "node_pair_half_extent_m", "node_scenery_half_extent_x_m"},
         "calibration.shipping_touch_waystone")
    need(num(shipping["ink_radius_px"], "calibration.shipping_touch_waystone.ink_radius_px") == 28,
         "calibration: shipping ink radius drifted")
    need(num(shipping["phone_touch_floor_px"],
             "calibration.shipping_touch_waystone.phone_touch_floor_px") >= 44,
         "calibration: 44 px accessibility floor lowered")
    need(num(shipping["default_layout_scale"],
             "calibration.shipping_touch_waystone.default_layout_scale") == 0.92,
         "calibration: shipping layout scale drifted")
    need(shipping["node_pair_half_extent_m"] == [0.63, 0.98],
         "calibration: node-pair extent drifted")
    need(num(shipping["node_scenery_half_extent_x_m"],
             "calibration.shipping_touch_waystone.node_scenery_half_extent_x_m") == 0.82,
         "calibration: node-scenery extent drifted")
    stage = obj(calibration["stage_zoom_geometry"], "calibration.stage_zoom_geometry")
    keys(stage, {"lattice_rows", "lattice_cols", "cell_m", "origin_xz_m",
                 "authored_jitter_fraction"}, "calibration.stage_zoom_geometry")
    need(stage == {"lattice_rows": 15, "lattice_cols": 7,
                   "cell_m": [5.142857142857143, 6.0], "origin_xz_m": [-36.0, -18.0],
                   "authored_jitter_fraction": [0.5, 0.4]},
         "calibration: lattice facts drifted")
    baseline = obj(calibration["baseline"], "calibration.baseline")
    expected_baseline = {
        "issue": 462,
        "status": "available",
        "production_source_sha": "52a56e726da70c2dd57254e8c6618682c7558f90",
        "artifact_head": "4fe17d40b51178fe2f9a1e92d848787b3dc337c7",
        "contact_sheet_index_capture_head": "d5346a369985e4b7ef3f852d7b8fd45276319889",
        "workflow_run": 32790383346,
        "frame_count": 168,
        "locale": "en",
        "generated_seeds": [717, 17634],
        "shapes": ["pad-landscape", "desktop-landscape", "phone-landscape"],
        "zoom_stop_indices": [0, 1, 2, 3],
        "poses": ["opening", "focused"],
        "readme_path": "docs/reviews/462/README.md",
        "summary_path": "docs/reviews/462/summary.md",
        "defect_ledger_path": "docs/reviews/462/defect-ledger.csv",
        "contact_sheet_index_path": "docs/reviews/462/contact-sheets/index.json",
        "evidence_scope": "desktop_xvfb_not_device",
        "device_evidence_status": "not_supplied",
    }
    need(baseline == expected_baseline, "calibration.baseline: #462 binding drifted")
    need(calibration["status"] == "baseline_available_quantitative_review_pending"
         and calibration["release_review_required"] is True,
         "calibration: baseline must be available while quantitative owner review remains required")

def validate_geometry(root: dict[str, Any]) -> None:
    geometry = obj(root["geometry"], "geometry")
    expected = {"road_corridor", "branch_fanout", "row_lane_envelope",
                "vigil_protected_zone", "terminus_protected_zone"}
    keys(geometry, expected, "geometry")
    schemas = {
        "road_corridor": {"physical_half_width_m", "world_clearance_m",
                          "waylight_max_width_ratio", "class"},
        "branch_fanout": {"common_departure_max_m", "sample_distance_m", "class"},
        "row_lane_envelope": {"row_half_extent_m", "lane_half_extent_m",
                              "minimum_forward_progress_m", "class"},
        "vigil_protected_zone": {"padding_m", "framing_margin_px", "class"},
        "terminus_protected_zone": {"padding_m", "framing_margin_px", "class"},
    }
    for profile_id, schema in schemas.items():
        profile = obj(geometry[profile_id], f"geometry.{profile_id}")
        keys(profile, schema, f"geometry.{profile_id}")
        need(profile["class"] == "provisional_owner_review",
             f"geometry.{profile_id}.class: expected provisional")
        for key, value in profile.items():
            if key != "class":
                need(num(value, f"geometry.{profile_id}.{key}") > 0,
                     f"geometry.{profile_id}.{key}: expected positive")
    need(num(geometry["road_corridor"]["waylight_max_width_ratio"],
             "geometry.road_corridor.waylight_max_width_ratio") <= 0.25,
         "geometry.road_corridor: waylight no longer narrow")
    need(geometry["branch_fanout"]["common_departure_max_m"]
         < geometry["branch_fanout"]["sample_distance_m"],
         "geometry.branch_fanout: sample must follow common departure")
    need(geometry["row_lane_envelope"]["row_half_extent_m"] < 5.142857142857143 / 2,
         "geometry.row_lane_envelope: crosses neighbouring row midpoint")
    need(geometry["row_lane_envelope"]["lane_half_extent_m"] < 3,
         "geometry.row_lane_envelope: crosses neighbouring lane midpoint")


def validate_hard(root: dict[str, Any]) -> dict[str, dict[str, Any]]:
    hard = indexed(root["hard"], "hard", HARD_IDS)
    gte_ids: set[str] = set()
    for metric_id, metric in hard.items():
        keys(metric, HARD_KEYS, f"hard.{metric_id}")
        text(metric["measure"], f"hard.{metric_id}.measure")
        need(metric["unit"] in HARD_UNITS, f"hard.{metric_id}.unit: unexpected")
        need(metric["op"] in {"lte", "gte"}, f"hard.{metric_id}.op: unexpected")
        num(metric["limit"], f"hard.{metric_id}.limit")
        need(metric["scope"] in {"every_profile", "layout_world", "focus_and_pan_bounds",
                                 "all_replays"}, f"hard.{metric_id}.scope: unexpected")
        need(metric["class"] in CLASSES, f"hard.{metric_id}.class: unexpected")
        need(isinstance(metric["provisional"], bool),
             f"hard.{metric_id}.provisional: expected boolean")
        need(integer(metric["owner"], f"hard.{metric_id}.owner") == HARD_OWNERS[metric_id],
             f"hard.{metric_id}.owner: wrong later owner")
        if metric["op"] == "gte":
            gte_ids.add(metric_id)
    need(gte_ids == REQUIRED_MINIMUM_IDS | OPTIONAL_MINIMUM_IDS,
         "hard: minimum metric set drifted from empty-set policy")
    touch = hard["node_touch_target_min_px"]
    need(touch["op"] == "gte" and num(touch["limit"], "hard.node_touch_target_min_px.limit") >= 44,
         "hard.node_touch_target_min_px: 44 px accessibility floor lowered")
    need(touch["class"] == "shipping_touch_waystone" and touch["provisional"] is False,
         "hard.node_touch_target_min_px: shipping classification drifted")
    for metric_id in ZERO_IDS:
        metric = hard[metric_id]
        need(metric["op"] == "lte" and num(metric["limit"], f"hard.{metric_id}.limit") == 0,
             f"hard.{metric_id}: immutable violation budget must be zero")
        need(metric["class"] == "immutable_zero_tolerance" and metric["provisional"] is False,
             f"hard.{metric_id}: immutable classification drifted")
    for metric_id in POSITIVE_FLOOR_IDS:
        metric = hard[metric_id]
        need(metric["op"] == "gte" and num(metric["limit"], f"hard.{metric_id}.limit") > 0
             and metric["class"] == "provisional_owner_review" and metric["provisional"] is True,
             f"hard.{metric_id}: expected positive provisional floor")
    return hard


def validate_soft(root: dict[str, Any]) -> None:
    soft = indexed(root["soft"], "soft", SOFT_IDS)
    total = 0.0
    for metric_id, metric in soft.items():
        keys(metric, SOFT_KEYS, f"soft.{metric_id}")
        text(metric["measure"], f"soft.{metric_id}.measure")
        need(metric["unit"] in SOFT_UNITS, f"soft.{metric_id}.unit: unexpected")
        direction = metric["direction"]
        need(direction in {"higher_is_better", "lower_is_better"},
             f"soft.{metric_id}.direction: unexpected")
        best, worst = num(metric["best"], f"soft.{metric_id}.best"), \
            num(metric["worst"], f"soft.{metric_id}.worst")
        need((direction == "higher_is_better" and best > worst)
             or (direction == "lower_is_better" and best < worst),
             f"soft.{metric_id}: best/worst contradict direction")
        text(metric["aggregation"], f"soft.{metric_id}.aggregation")
        weight = num(metric["weight"], f"soft.{metric_id}.weight")
        need(0 < weight < 1, f"soft.{metric_id}.weight: expected (0,1)")
        total += weight
        need(integer(metric["owner"], f"soft.{metric_id}.owner") == SOFT_OWNERS[metric_id],
             f"soft.{metric_id}.owner: wrong later owner")
        text(metric["rationale"], f"soft.{metric_id}.rationale")
        need(text(metric["empty_policy"], f"soft.{metric_id}.empty_policy")
             == SOFT_EMPTY_POLICIES[metric_id],
             f"soft.{metric_id}.empty_policy: governed policy drifted")
    need(math.isclose(total, 1.0, abs_tol=1e-9),
         f"soft: weights sum to {total:.12f}, expected 1.0")


def validate_grammar(root: dict[str, Any]) -> None:
    need(root["hierarchy"] == HIERARCHY, "hierarchy: visual order drifted")
    renderer: dict[str, dict[str, Any]] = {}
    for index, raw in enumerate(arr(root["renderer"], "renderer")):
        row = obj(raw, f"renderer[{index}]")
        keys(row, {"id", "required", "owner"}, f"renderer[{index}]")
        item_id = text(row["id"], f"renderer[{index}].id")
        need(item_id not in renderer, f"renderer: duplicate ID {item_id!r}")
        renderer[item_id] = row
    need(set(renderer) == set(RENDERER), "renderer: unknown or missing invariant ID")
    for item_id, owner in RENDERER.items():
        need(renderer[item_id]["required"] is True and renderer[item_id]["owner"] == owner,
             f"renderer.{item_id}: required/owner drifted")

    zones: dict[str, dict[str, Any]] = {}
    for index, raw in enumerate(arr(root["zones"], "zones")):
        zone = obj(raw, f"zones[{index}]")
        keys(zone, {"id", "density_role", "height_role", "occupancy_ratio", "route_relation",
                    "class"}, f"zones[{index}]")
        zone_id = text(zone["id"], f"zones[{index}].id")
        need(zone_id not in zones, f"zones: duplicate ID {zone_id!r}")
        zones[zone_id] = zone
        text(zone["density_role"], f"zones.{zone_id}.density_role")
        text(zone["height_role"], f"zones.{zone_id}.height_role")
        text(zone["route_relation"], f"zones.{zone_id}.route_relation")
        need(zone["class"] == "provisional_owner_review",
             f"zones.{zone_id}.class: expected provisional")
        bounds = arr(zone["occupancy_ratio"], f"zones.{zone_id}.occupancy_ratio")
        need(len(bounds) == 2
             and 0 <= num(bounds[0], f"zones.{zone_id}.occupancy_ratio[0]")
             <= num(bounds[1], f"zones.{zone_id}.occupancy_ratio[1]") <= 1,
             f"zones.{zone_id}.occupancy_ratio: expected ordered [0,1] bounds")
    need(set(zones) == ZONES, "zones: unknown or missing zone ID")


def validate_provisional(root: dict[str, Any], hard: dict[str, dict[str, Any]]) -> None:
    raw = arr(root["provisional_ids"], "provisional_ids")
    need(all(isinstance(value, str) and value for value in raw),
         "provisional_ids: expected strings")
    need(len(raw) == len(set(raw)), "provisional_ids: duplicate ID")
    need(raw == sorted(raw), "provisional_ids: must be sorted")
    expected = ({metric_id for metric_id, metric in hard.items() if metric["provisional"]}
                | SOFT_IDS | {f"geometry.{key}" for key in root["geometry"]}
                | {f"zones.{zone}" for zone in ZONES})
    need(set(raw) == expected,
         "provisional_ids: does not match provisional hard/soft/geometry/zone values")
    review = arr(root["review_items"], "review_items")
    need(len(review) >= 5 and all(isinstance(item, str) and item.strip() for item in review),
         "review_items: expected at least five concrete review items")
    need(len(review) == len(set(review)), "review_items: duplicate item")
    review_text = " ".join(review)
    for index in range(1, 10):
        defect_id = f"D462-{index:03d}"
        need(defect_id in review_text,
             f"review_items: missing #462 defect binding {defect_id}")


def validate(raw: Any) -> dict[str, Any]:
    root = obj(raw, "root")
    keys(root, ROOT, "root")
    need(integer(root["schema_version"], "schema_version") == 1, "schema_version: expected 1")
    need(root["contract_version"] == "2.0.0", "contract_version: expected 2.0.0")
    need(root["registry_id"] == "map-quality-v2", "registry_id: expected map-quality-v2")
    need(root["evaluation_order"] == ["hard", "soft"],
         "evaluation_order: hard must precede soft")
    validate_profiles(root)
    validate_empty_policies(root)
    validate_calibration(root)
    validate_geometry(root)
    hard = validate_hard(root)
    validate_soft(root)
    validate_grammar(root)
    validate_provisional(root, hard)
    return {"hard": len(hard), "soft": len(root["soft"]),
            "provisional": len(root["provisional_ids"])}


def fail_fixture(name: str, fixture: Any, fragment: str) -> None:
    try:
        validate(fixture)
    except ContractError as error:
        need(fragment in str(error), f"self-test {name}: wrong failure: {error}")
        print(f"self-test {name}: correctly failed")
        return
    raise ContractError(f"self-test {name}: injected fault was not detected")


def self_test(raw: Any) -> None:
    validate(raw)
    fixture = copy.deepcopy(raw); fixture["hard"].append(copy.deepcopy(fixture["hard"][0]))
    fail_fixture("duplicate metric ID", fixture, "duplicate metric id")
    fixture = copy.deepcopy(raw); fixture["soft"][0]["id"] = "looks_good"
    fail_fixture("unknown metric ID", fixture, "unknown metric IDs")
    fixture = copy.deepcopy(raw); fixture["unexpected"] = True
    fail_fixture("unknown field", fixture, "unknown fields")
    fixture = copy.deepcopy(raw); fixture["soft"][0]["weight"] += 0.01
    fail_fixture("weight drift", fixture, "weights sum")
    fixture = copy.deepcopy(raw)
    next(row for row in fixture["hard"] if row["id"] == "node_touch_target_min_px")["limit"] = 43
    fail_fixture("touch floor", fixture, "44 px accessibility floor lowered")
    fixture = copy.deepcopy(raw)
    next(row for row in fixture["hard"] if row["id"] == "row_lane_envelope_excess_m")["limit"] = 0.5
    fail_fixture("row envelope immutable zero", fixture, "immutable violation budget must be zero")
    fixture = copy.deepcopy(raw); fixture["provisional_ids"].pop()
    fail_fixture("provisional list", fixture, "does not match")
    fixture = copy.deepcopy(raw); fixture["soft"][0]["unit"] = "score"
    fail_fixture("unit vocabulary", fixture, "unit: unexpected")
    fixture = copy.deepcopy(raw); fixture["soft"][0]["empty_policy"] = "guess"
    fail_fixture("empty policy", fixture, "empty_policy: governed policy drifted")
    fixture = copy.deepcopy(raw); fixture["calibration"]["baseline"]["workflow_run"] = 0
    fail_fixture("baseline binding", fixture, "#462 binding drifted")
    fixture = copy.deepcopy(raw); fixture["review_items"] = ["D462-001 only"] * 5
    fail_fixture("baseline defect coverage", fixture, "duplicate item")
    fixture = copy.deepcopy(raw); fixture["review_items"][-1] = "owner review without D462-009"
    fixture["review_items"] = [item.replace("D462-009", "D462-008") for item in fixture["review_items"]]
    fail_fixture("baseline defect coverage", fixture, "missing #462 defect binding D462-009")
    print("self-test OK (12 fail-closed mutation fixtures)")


def digest(raw: Any) -> str:
    data = json.dumps(raw, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(data).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", type=Path, default=DEFAULT)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    raw = json.loads(args.registry.read_text(encoding="utf-8"))
    if args.self_test:
        self_test(raw)
    else:
        result = validate(raw)
        print(f"map quality v2 OK schema=1 contract=2.0.0 hard={result['hard']} "
              f"soft={result['soft']} provisional={result['provisional']} digest={digest(raw)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ContractError, OSError, json.JSONDecodeError) as error:
        print(f"map quality v2 FAILED: {error}", file=sys.stderr)
        raise SystemExit(1)
