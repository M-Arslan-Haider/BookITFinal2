package com.metaxperts.order_booking_app

// ═════════════════════════════════════════════════════════════════════════════
// NativeDBHelper — SQLite helper for location_tracking table
//
// Unchanged from original except extracted to its own file for clarity.
// Used by:
//   - LocationMonitorService (insert rows)
//   - LocationUploadWorker (read unposted, mark posted)
// ═════════════════════════════════════════════════════════════════════════════

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

class NativeDBHelper(context: Context) :
    SQLiteOpenHelper(context, "bookIt.db", null, 1) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """CREATE TABLE IF NOT EXISTS location_tracking (
                locationtracking_id   TEXT PRIMARY KEY,
                locationtracking_date TEXT,
                locationtracking_time TEXT,
                user_id               TEXT,
                lat_in                TEXT,
                lng_in                TEXT,
                booker_name           TEXT,
                designation           TEXT,
                posted                INTEGER DEFAULT 0,
                company_code          TEXT DEFAULT ''
            )"""
        )
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {}

    fun insertLocationRow(
        id:          String,
        date:        String,
        time:        String,
        userId:      String,
        lat:         String,
        lng:         String,
        bookerName:  String,
        designation: String,
        companyCode: String
    ) {
        val cv = ContentValues().apply {
            put("locationtracking_id",   id)
            put("locationtracking_date", date)
            put("locationtracking_time", time)
            put("user_id",               userId)
            put("lat_in",                lat)
            put("lng_in",                lng)
            put("booker_name",           bookerName)
            put("designation",           designation)
            put("posted",                0)
            put("company_code",          companyCode)
        }
        writableDatabase.insertWithOnConflict(
            "location_tracking", null, cv, SQLiteDatabase.CONFLICT_IGNORE
        )
    }

    fun getUnpostedRows(): List<Map<String, String>> {
        val rows   = mutableListOf<Map<String, String>>()
        val cursor = readableDatabase.rawQuery(
            "SELECT * FROM location_tracking WHERE posted = 0 ORDER BY locationtracking_date, locationtracking_time",
            null
        )
        cursor.use {
            while (it.moveToNext()) {
                val row = mutableMapOf<String, String>()
                for (i in 0 until it.columnCount) row[it.getColumnName(i)] = it.getString(i) ?: ""
                rows.add(row)
            }
        }
        return rows
    }

    fun markPosted(ids: List<String>) {
        if (ids.isEmpty()) return
        writableDatabase.execSQL(
            "UPDATE location_tracking SET posted = 1 WHERE locationtracking_id IN (${ids.joinToString(",") { "?" }})",
            ids.toTypedArray()
        )
    }
}