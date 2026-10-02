from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from parser import (
    parse_all_specialties,
    parse_doctors_by_specialty,
    parse_doctor_slots,
)

app = FastAPI(title="Omsk Health Notifier API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 1. Получить каталог специальностей (Акушерство, Терапевт и т.д.)
@app.get("/api/specialties")
def get_specialties():
    specialties = parse_all_specialties()
    return {
        "status": "success",
        "count": len(specialties),
        "specialties": specialties
    }

# 2. Получить список врачей по переданной ссылке специальности
@app.get("/api/doctors")
def get_doctors(url: str = Query(..., description="Ссылка на список врачей специальности")):
    hospitals = parse_doctors_by_specialty(url)
    return {
        "status": "success",
        "hospitals": hospitals
    }

# 3. Получить талоны выбранного врача
@app.get("/api/slots")
def get_slots(url: str = Query(..., description="Ссылка на расписание врача")):
    slots = parse_doctor_slots(url)
    return {
        "status": "success",
        "count": len(slots),
        "slots": slots
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)