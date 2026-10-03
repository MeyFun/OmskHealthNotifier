import re
import requests
from bs4 import BeautifulSoup

BASE_URL = "https://omskzdrav.ru"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "ru-RU,ru;q=0.9",
}


def parse_all_specialties():
    """1. Парсит глобальный список специальностей"""
    url = f"{BASE_URL}/service/schedule/profiles"
    try:
        response = requests.get(url, headers=HEADERS, timeout=10)
        if response.status_code != 200:
            return []
    except Exception as e:
        print(f"Ошибка загрузки специальностей: {e}")
        return []

    soup = BeautifulSoup(response.text, "html.parser")
    specialties = []

    links = soup.find_all("a", href=re.compile(r"/service/schedule/\d+/0/doctors"))

    for link in links:
        title = link.text.strip()
        href = link.get("href", "")
        if title and href:
            full_url = href if href.startswith("http") else f"{BASE_URL}{href}"
            spec_id = href.split("/")[3]
            
            specialties.append({
                "id": spec_id,
                "title": title,
                "url": full_url
            })

    return specialties


def parse_doctors_by_specialty(doctors_url: str):
    """
    2. Парсит полный список врачей по специальности с жесткой фильтрацией мусора и шапок
    """
    if not doctors_url.startswith("http"):
        doctors_url = f"{BASE_URL}{doctors_url}"

    if "?" in doctors_url:
        if "per_page" not in doctors_url:
            doctors_url += "&per_page=999999"
    else:
        doctors_url += "?per_page=999999"

    try:
        response = requests.get(doctors_url, headers=HEADERS, timeout=15)
        if response.status_code != 200:
            return []
    except Exception as e:
        print(f"Ошибка загрузки врачей: {e}")
        return []

    soup = BeautifulSoup(response.text, "html.parser")
    hospitals_data = []

    # Слова-мусор из заголовков таблицы или служебных мета-данных
    BAD_KEYWORDS = [
        "специалист", "специальность", "участок", "стоимость", 
        "ближайшая запись", "оценка", "бесплатно", "врачей:"
    ]

    # Находим все блоки аккордеонов/больниц (пропускаем tr и шапки)
    # На omskzdrav реальные больницы лежат в блоках с названиями ЛПУ
    hospital_sections = soup.find_all(["div", "section", "fieldset"], class_=re.compile(r"lpu|hospital|clinic|group|panel|block|accordion", re.I))

    for section in hospital_sections:
        # Ищем заголовок именно больницы (обычно h2, h3, h4, legend или div.lpu-title)
        header = section.find(["h2", "h3", "h4", "h5", "legend", "div", "a"], class_=re.compile(r"title|name|header|lpu", re.I))
        if not header:
            continue

        hospital_name = header.text.strip()
        
        # Проверяем, что название больницы — это не мусорная строка шапки
        h_name_lower = hospital_name.lower()
        if any(bad in h_name_lower for bad in BAD_KEYWORDS) or len(hospital_name) < 5:
            continue

        # Собираем врачей ТОЛЬКО внутри текущего блока больницы
        doc_links = section.find_all("a", href=re.compile(r"/service/schedule/\d+/timetable"))
        doctors = []
        seen_doc_ids = set()

        for a in doc_links:
            name = a.text.strip()
            href = a.get("href", "")
            
            if name and href:
                n_lower = name.lower()
                # Пропускаем, если имя врача совпадает со словами шапки таблицы
                if any(bad in n_lower for bad in BAD_KEYWORDS):
                    continue

                doc_id = href.split("/")[3]
                if doc_id not in seen_doc_ids:
                    seen_doc_ids.add(doc_id)
                    full_url = href if href.startswith("http") else f"{BASE_URL}{href}"
                    doctors.append({
                        "id": doc_id,
                        "name": name,
                        "schedule_url": full_url
                    })

        # Добавляем больницу, только если у неё есть реальные врачи
        if doctors:
            hospitals_data.append({
                "hospital_name": hospital_name,
                "doctors": doctors
            })

    # Запасной вариант: если структура блоков не нашлась вообще (крайний случай)
    if not hospitals_data:
        doc_links = soup.find_all("a", href=re.compile(r"/service/schedule/\d+/timetable"))
        all_doctors = []
        seen_ids = set()

        for a in doc_links:
            name = a.text.strip()
            href = a.get("href", "")
            if name and href:
                if any(bad in name.lower() for bad in BAD_KEYWORDS):
                    continue
                doc_id = href.split("/")[3]
                if doc_id not in seen_ids:
                    seen_ids.add(doc_id)
                    full_url = href if href.startswith("http") else f"{BASE_URL}{href}"
                    all_doctors.append({
                        "id": doc_id,
                        "name": name,
                        "schedule_url": full_url
                    })

        if all_doctors:
            hospitals_data.append({
                "hospital_name": "Медучреждения Омска и области",
                "doctors": all_doctors
            })

    return hospitals_data

def parse_doctor_slots(doctor_url: str):
    """3. Парсит расписание конкретного врача"""
    if not doctor_url.startswith("http"):
        if not doctor_url.startswith("/"):
            doctor_url = "/" + doctor_url
        doctor_url = f"{BASE_URL}{doctor_url}"

    try:
        response = requests.get(doctor_url, headers=HEADERS, timeout=8)
        if response.status_code != 200:
            return []
    except Exception as e:
        print(f"Ошибка при запросе расписания врача: {e}")
        return []

    try:
        soup = BeautifulSoup(response.text, "html.parser")
        parsed_slots = []

        cells = soup.find_all("td", class_=re.compile(r"\bfree\b"))

        for cell in cells:
            slot_id = cell.get("id", "")
            classes = cell.get("class", [])
            rel_info = cell.get("rel", "")

            time_span = cell.find("span", class_="ttg-cell-time")
            time_text = time_span.text.strip() if time_span else cell.text.strip()

            date_text = ""
            if rel_info:
                date_text = rel_info.rsplit(" ", 1)[0] if " " in rel_info else rel_info

            is_videochat = "videochatFree" in classes
            slot_type = "videochatFree" if is_videochat else "free"

            parsed_slots.append({
                "id": slot_id,
                "time": time_text,
                "date": date_text,
                "type": slot_type,
                "raw_rel": rel_info
            })

        return parsed_slots
    except Exception as e:
        print(f"Ошибка парсинга HTML: {e}")
        return []