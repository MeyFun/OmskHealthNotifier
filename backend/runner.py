import json
import os
import sys
from parser import parse_all_specialties, parse_doctors_by_specialty

def build_full_data():
    print("=== Начало сборки данных omskzdrav.ru ===")
    
    # 1. Загружаем специальности
    specialties = parse_all_specialties()
    print(f"Найдено специальностей: {len(specialties)}")

    full_structure = []

    # 2. Обходим специальности и собираем медучреждения с врачами
    for index, spec in enumerate(specialties):
        print(f"[{index + 1}/{len(specialties)}] Загрузка: {spec['title']}...")
        hospitals = parse_doctors_by_specialty(spec['url'])
        
        full_structure.append({
            "id": spec["id"],
            "title": spec["title"],
            "url": spec["url"],
            "hospitals": hospitals
        })

    result = {
        "status": "success",
        "count": len(full_structure),
        "specialties": full_structure
    }

    # 3. Сохраняем в корень проекта
    output_path = os.path.join(os.path.dirname(__file__), "..", "data.json")
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print(f"=== Сборка завершена. Файл сохранен в {output_path} ===")

if __name__ == "__main__":
    build_full_data()