from typing import Dict

def marks_to_grade_points(marks: int, scale: Dict[tuple, float]) -> float:
    """
    Converts a marks value to grade points based on a given scale.
    Example scale mapping: {(90, 100): 10.0, (80, 89): 9.0}
    """
    for (low, high), gp in scale.items():
        if low <= marks <= high:
            return gp
    return 0.0  # Below threshold

def compute_sgpa(marks_dict: Dict[str, int], credits_map: Dict[str, int], scale: Dict[tuple, float]) -> float:
    """
    Computes SGPA = Σ(grade_points[i] × credits[i]) / Σ(credits[i])
    """
    total_credits = sum(credits_map.values())
    if total_credits == 0:
        return 0.0
        
    weighted_sum = sum(
        marks_to_grade_points(marks, scale) * credits_map.get(subj, 0)
        for subj, marks in marks_dict.items()
    )
    
    return round(weighted_sum / total_credits, 2)

def compute_cgpa(sgpa_list: list[float], total_credits_list: list[int]) -> float:
    """
    Computes CGPA across multiple semesters
    """
    if not sgpa_list or not total_credits_list or len(sgpa_list) != len(total_credits_list):
        return 0.0
        
    numerator = sum(sgpa * credits for sgpa, credits in zip(sgpa_list, total_credits_list))
    denominator = sum(total_credits_list)
    
    if denominator == 0:
        return 0.0
    return round(numerator / denominator, 2)
