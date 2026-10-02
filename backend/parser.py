import requests
from bs4 import BeautifulSoup
import re

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "ru-RU,ru;q=0.9",
}

BASE_URL = "https://omskzdrav.ru"


def parse_all_specialties():
    """
    1. Парсит глобальный список специальностей (Фото 1)
    URL: https://omskzdrav.ru/service/schedule/profiles
    """
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

    # Ищем все ссылки на специальности в каталоге
    links = soup.find_all("a", href=re.compile(r"/service/schedule/\d+/0/doctors"))

    for link in links:
        title = link.text.strip()
        href = link.get("href", "")
        if title and href:
            full_url = href if href.startswith("http") else f"{BASE_URL}{href}"
            spec_id = href.split("/")[3]  # извлекаем ID специальности (например 550101000000081)
            
            specialties.append({
                "id": spec_id,
                "title": title,
                "url": full_url
            })

    return specialties


def parse_doctors_by_specialty(doctors_url: str):
    """
    2. Парсит полный список врачей по специальности (Фото 2)
    Запрашивает per_page=999999, чтобы вернуть ВСЕХ врачей без ограничения пагинации.
    """
    if not doctors_url.startswith("http"):
        doctors_url = f"{BASE_URL}{doctors_url}"

    # Добавляем параметр per_page=999999 для загрузки всех врачей на одной странице
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

    # Находим все секции/блоки учреждений
    # На omskzdrav блоки больниц обычно оборачиваются в контейнеры с названием ЛПУ
    hospital_sections = soup.find_all(["div", "section", "fieldset"], class_=re.compile(r"lpu|hospital|clinic|group|panel|block|accordion", re.I))

    # Если структура с блоками найдена
    if hospital_sections:
        for section in hospital_sections:
            # Ищем заголовок больницы внутри блока
            header = section.find(["h2", "h3", "h4", "h5", "legend", "div", "a"], class_=re.compile(r"title|name|header|lpu", re.I))
            hospital_name = header.text.strip() if header else None

            # Ищем все ссылки на врачей внутри этой больницы
            doc_links = section.find_all("a", href=re.compile(r"/service/schedule/\d+/timetable"))
            doctors = []

            for a in doc_links:
                name = a.text.strip()
                href = a.get("href", "")
                if name and href:
                    full_url = href if href.startswith("http") else f"{BASE_URL}{href}"
                    doc_id = href.split("/")[3]
                    doctors.append({
                        "id": doc_id,
                        "name": name,
                        "schedule_url": full_url
                    })

            if doctors and hospital_name:
                hospitals_data.append({
                    "hospital_name": hospital_name,
                    "doctors": doctors
                })

    # Если структурированные блоки не определились — собираем всех врачей сплошным списком
    if not hospitals_data:
        doc_links = soup.find_all("a", href=re.compile(r"/service/schedule/\d+/timetable"))
        all_doctors = []
        seen_ids = set()

        for a in doc_links:
            name = a.text.strip()
            href = a.get("href", "")
            if name and href:
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
                "hospital_name": "Все медучреждения Омска и области",
                "doctors": all_doctors
            })

    return hospitals_data


def parse_doctor_slots(doctor_url: str):
    """
    3. Парсит таблицу талонов конкретного врача
    """
    if not doctor_url.startswith("http"):
        # Если передан относительный путь вида /service/schedule/...
        if not doctor_url.startswith("/"):
            doctor_url = "/" + doctor_url
        doctor_url = f"{BASE_URL}{doctor_url}"

    try:
        # Устанавливаем таймаут 8 секунд, чтобы не вешать Swagger/браузер
        response = requests.get(doctor_url, headers=HEADERS, timeout=8)
        if response.status_code != 200:
            print(f"Ошибка: статус ответа {response.status_code}")
            return []
    except requests.exceptions.Timeout:
        print("Ошибка: Превышено время ожидания ответа от omskzdrav.ru")
        return []
    except Exception as e:
        print(f"Ошибка при запросе расписания врача: {e}")
        return []

    try:
        soup = BeautifulSoup(response.text, "html.parser")
        parsed_slots = []

        # Ищем ячейки со свободными талонами
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