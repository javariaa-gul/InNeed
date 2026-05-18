import os, time, math
import psycopg2, psycopg2.extras
from fastapi import FastAPI
from pydantic import BaseModel
from typing import List
from geopy.distance import geodesic

app = FastAPI(title="Apka Hunar AI Matching Engine v3.5")

# --- AI Hyperparameters (Model ki Settings) ---
WALK_SPEED_KMH = 5.0
CAR_SPEED_KMH = 45.0  # Average city speed with traffic
READY_BUFFER_MINS = 15.0 # Prep time for seeker
DECAY_FACTOR = 0.05 # Distance penalty strength

class MatchRequest(BaseModel):
    job_id: int
    lat: float
    lon: float
    urgency_minutes: int  # Poster's deadline

class MatchResult(BaseModel):
    targeted_seeker_ids: List[int]
    ranked_seekers: List[dict]
    total_matches: int

def calculate_time_score(dist_km: float, deadline_mins: int) -> float:
    """
    Core AI Scoring Logic:
    Calculates a probability score (0 to 100) based on reachability.
    """
    effective_time = deadline_mins - READY_BUFFER_MINS
    if effective_time <= 0: return 0.0
    
    # Travel times in minutes
    t_car = (dist_km / CAR_SPEED_KMH) * 60
    t_walk = (dist_km / WALK_SPEED_KMH) * 60
    
    # 1. Hard Filter: Agar car se bhi late ho jaye, toh 0 score
    if t_car > effective_time:
        return 0.0
    
    # 2. Probability Scoring:
    # Agar walk se pahunch sakta hai (Super Seeker) -> High Score
    if t_walk <= effective_time:
        score = 90.0 + (10.0 * (1 - (t_walk / effective_time)))
    else:
        # Agar car chahiye -> Medium Score based on buffer
        # Buffer ratio: jitna car time deadline se kam hoga, score utna acha hoga
        buffer_ratio = (effective_time - t_car) / effective_time
        score = 50.0 + (40.0 * buffer_ratio)
        
    return round(score, 2)

@app.post("/match", response_model=MatchResult)
def match_engine(req: MatchRequest):
    # Database se sirf active workers uthao (Skills ignore)
    conn = None
    try:
        conn = psycopg2.connect(
            host=os.getenv("DATABASE_HOST", "db"),
            user=os.getenv("DATABASE_USER", "user_admin"),
            password=os.getenv("DATABASE_PASSWORD", "password123"),
            database=os.getenv("DATABASE_NAME", "apka_hunar_db")
        )
        
        seekers = []
        with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
            # ✅ Fixed: Use proper column names, handle optional fields
            cur.execute('''
                SELECT 
                    id, 
                    "fullName", 
                    COALESCE(lat, 0) as lat,
                    COALESCE(lon, 0) as lon
                FROM users 
                WHERE "activeRole" = %s
                AND (lat IS NOT NULL AND lon IS NOT NULL AND lat != 0 AND lon != 0)
            ''', ('worker',))
            rows = cur.fetchall()
            
        poster_loc = (req.lat, req.lon)
        
        for row in rows:
            try:
                lat = float(row['lat'])
                lon = float(row['lon'])
                if lat == 0 or lon == 0:
                    continue
                    
                seeker_loc = (lat, lon)
                dist = geodesic(poster_loc, seeker_loc).km
                
                # AI Inference Step
                match_score = calculate_time_score(dist, req.urgency_minutes)
                
                if match_score > 0:
                    seekers.append({
                        "id": row['id'],
                        "name": row['fullName'],
                        "distance_km": round(dist, 2),
                        "ai_score": match_score,
                        "confidence": "High" if match_score > 80 else "Fair"
                    })
            except Exception as row_error:
                print(f"Error processing seeker {row.get('id')}: {row_error}")
                continue
        
        # Sort by AI Score (Highest confidence first)
        seekers.sort(key=lambda x: x["ai_score"], reverse=True)
        
        return MatchResult(
            targeted_seeker_ids=[s["id"] for s in seekers[:50]],  # Top 50 matches
            ranked_seekers=seekers[:50],
            total_matches=len(seekers)
        )
        
    except psycopg2.Error as db_error:
        print(f"Database Error: {db_error}")
        # ✅ Return empty result instead of 502 (graceful fallback)
        return MatchResult(
            targeted_seeker_ids=[],
            ranked_seekers=[],
            total_matches=0
        )
    except Exception as error:
        print(f"Unexpected Error in /match: {error}")
        return MatchResult(
            targeted_seeker_ids=[],
            ranked_seekers=[],
            total_matches=0
        )
    finally:
        if conn:
            conn.close()

@app.get("/health")
def health():
    """Health check endpoint"""
    try:
        conn = psycopg2.connect(
            host=os.getenv("DATABASE_HOST", "db"),
            user=os.getenv("DATABASE_USER", "user_admin"),
            password=os.getenv("DATABASE_PASSWORD", "password123"),
            database=os.getenv("DATABASE_NAME", "apka_hunar_db")
        )
        conn.close()
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        return {"status": "unhealthy", "database": "disconnected", "error": str(e)}