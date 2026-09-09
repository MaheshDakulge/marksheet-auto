from typing import List, Dict, Any
from collections import Counter
import statistics


class AnalyticsService:
    def compute(self, results: List[Dict[str, Any]]) -> Dict[str, Any]:
        sgpa_values = [float(r["sgpa"]) for r in results if r.get("sgpa") is not None]
        statuses = [r.get("status", "pending") for r in results]

        pass_count = statuses.count("pass")
        fail_count = statuses.count("fail")
        atkt_count = statuses.count("atkt")
        absent_count = statuses.count("absent")

        avg_sgpa = round(statistics.mean(sgpa_values), 2) if sgpa_values else 0.0
        top_sgpa = round(max(sgpa_values), 2) if sgpa_values else 0.0
        min_sgpa = round(min(sgpa_values), 2) if sgpa_values else 0.0

        # FIX: above/below average counts were missing entirely
        above_avg_count = sum(1 for s in sgpa_values if s >= avg_sgpa)
        below_avg_count = sum(1 for s in sgpa_values if s < avg_sgpa)

        # Toppers — top 5 by SGPA (PRD says top 3 shown in card but fetch 5 for full list)
        sorted_results = sorted(
            results,
            key=lambda r: (float(r.get("sgpa") or 0), float(r.get("total_egp") or 0)),
            reverse=True,
        )
        toppers = []
        for r in sorted_results[:5]:
            student = r.get("students") or {}
            toppers.append({
                "prn": r["student_prn"],
                "name": student.get("name", "Unknown"),
                "sgpa": r.get("sgpa"),
                "rank": r.get("rank"),
                "status": r.get("status"),
            })

        # Grade distribution + subject averages across all subject_marks rows
        grade_counts: Counter = Counter()
        subject_gp_sums: Dict[str, List[float]] = {}

        for r in results:
            for mark in r.get("subject_marks", []):
                grade = mark.get("grade_obtained")
                if grade:
                    grade_counts[grade] += 1
                course = mark.get("course_name") or mark.get("course_code") or "Unknown"
                gp = mark.get("grade_point")
                if gp is not None:
                    subject_gp_sums.setdefault(course, []).append(float(gp))

        subject_averages = sorted(
            [
                {"subject": subj, "avg_gp": round(statistics.mean(gps), 2)}
                for subj, gps in subject_gp_sums.items()
            ],
            key=lambda x: x["avg_gp"],
            reverse=True,
        )

        # SGPA histogram buckets
        buckets: Dict[str, int] = {"<6": 0, "6-7": 0, "7-8": 0, "8-9": 0, "9-10": 0}
        for s in sgpa_values:
            if s < 6:
                buckets["<6"] += 1
            elif s < 7:
                buckets["6-7"] += 1
            elif s < 8:
                buckets["7-8"] += 1
            elif s < 9:
                buckets["8-9"] += 1
            else:
                buckets["9-10"] += 1

        return {
            "total_students": len(results),
            "pass_count": pass_count,
            "fail_count": fail_count,
            "atkt_count": atkt_count,
            "absent_count": absent_count,
            "avg_sgpa": avg_sgpa,
            "top_sgpa": top_sgpa,
            "min_sgpa": min_sgpa,
            # FIX: was missing from original
            "above_avg_count": above_avg_count,
            "below_avg_count": below_avg_count,
            "toppers": toppers,
            "grade_distribution": dict(grade_counts),
            "subject_averages": subject_averages,
            "sgpa_histogram": [{"range": k, "count": v} for k, v in buckets.items()],
        }
