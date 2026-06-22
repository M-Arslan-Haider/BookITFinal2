package com.metaxperts.order_booking_app

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

class BatteryRepository(context: Context) {

    private val dbHelper = BatteryDatabaseHelper(context)

    fun insertBatteryEvent(
        userId: String,
        userName: String,
        designation: String,
        companyCode: String,
        latIn: Double,
        lngIn: Double,
        batteryPercent: Int,
        detectTime: String
    ): Long {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put("user_id", userId)
            put("user_name", userName)
            put("designation", designation)
            put("company_code", companyCode)
            put("lat_in", latIn.toString())
            put("lng_in", lngIn.toString())
            put("battery_percentage", batteryPercent)
            put("detect_time", detectTime)
            put("posted", 0)
        }
        return db.insert("battery_low_log", null, values)
    }

    fun getUnpostedEvents(): List<BatteryLowEvent> {
        val db = dbHelper.readableDatabase
        val cursor = db.query(
            "battery_low_log",
            null,
            "posted = ?",
            arrayOf("0"),
            null, null, "detect_time ASC"
        )
        val events = mutableListOf<BatteryLowEvent>()
        while (cursor.moveToNext()) {
            events.add(BatteryLowEvent(
                id = cursor.getLong(cursor.getColumnIndexOrThrow("id")),
                userId = cursor.getString(cursor.getColumnIndexOrThrow("user_id")),
                userName = cursor.getString(cursor.getColumnIndexOrThrow("user_name")),
                designation = cursor.getString(cursor.getColumnIndexOrThrow("designation")),
                companyCode = cursor.getString(cursor.getColumnIndexOrThrow("company_code")),
                latIn = cursor.getString(cursor.getColumnIndexOrThrow("lat_in")),
                lngIn = cursor.getString(cursor.getColumnIndexOrThrow("lng_in")),
                battery = cursor.getInt(cursor.getColumnIndexOrThrow("battery_percentage")),
                detectTime = cursor.getString(cursor.getColumnIndexOrThrow("detect_time")),
                posted = cursor.getInt(cursor.getColumnIndexOrThrow("posted"))
            ))
        }
        cursor.close()
        return events
    }

    fun markAsPosted(ids: List<Long>) {
        val db = dbHelper.writableDatabase
        val contentValues = ContentValues().apply { put("posted", 1) }
        db.update("battery_low_log", contentValues, "id IN (${ids.joinToString(",")})", null)
    }

    fun hasTodayEvent(userId: String): Boolean {
        val db = dbHelper.readableDatabase
        val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault())
            .format(java.util.Date())
        val cursor = db.query(
            "battery_low_log",
            arrayOf("id"),
            "user_id = ? AND substr(detect_time, 1, 10) = ? AND posted = ?",
            arrayOf(userId, today, "0"),
            null, null, null, "1"
        )
        val exists = cursor.count > 0
        cursor.close()
        return exists
    }

    data class BatteryLowEvent(
        val id: Long,
        val userId: String,
        val userName: String,
        val designation: String,
        val companyCode: String,
        val latIn: String,
        val lngIn: String,
        val battery: Int,
        val detectTime: String,
        val posted: Int
    )

    private class BatteryDatabaseHelper(context: Context) :
        SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

        companion object {
            private const val DATABASE_NAME = "battery_monitor.db"
            private const val DATABASE_VERSION = 2
        }

        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL("""
                CREATE TABLE battery_low_log (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id TEXT NOT NULL,
                    user_name TEXT NOT NULL,
                    designation TEXT,
                    company_code TEXT,
                    lat_in TEXT,
                    lng_in TEXT,
                    battery_percentage INTEGER NOT NULL,
                    detect_time TEXT NOT NULL,
                    posted INTEGER DEFAULT 0,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            db.execSQL("DROP TABLE IF EXISTS battery_low_log")
            onCreate(db)
        }
    }
}