package com.metaxperts.order_booking_app

// ═════════════════════════════════════════════════════════════════════════════
// PowerStatusDBHelper
//
// Local SQLite store for the "power-status heartbeat" feature:
//   every 5 minutes (while the app/service is alive) a row is written with
//   {user_id, user_name, city, designation, battery%, status="online", timestamp}.
//
// Mirrors the server-side table:
//   ID            NUMBER          (server sequence — assigned on insert)
//   USER_ID       VARCHAR2(50)
//   USER_NAME     VARCHAR2(60)
//   CITY          VARCHAR2(50)
//   DESIGNATION   VARCHAR2(50)
//   BATTERY       NUMBER(5,2)
//   STATUS        VARCHAR2(...)   -- always "online" for rows written by this app
//   TIMESTAMP     (date/time of the heartbeat)
//
// This is a SEPARATE database file from NativeDBHelper's location DB, so it
// can be dropped into the project without touching existing tables/migrations.
//
// Writes are pure local SQLite — they succeed even with no network, which is
// exactly what's needed for the offline case ("agar offline ho ... locally
// database main har 5 min bad ... save ho jata jaye").
// ═════════════════════════════════════════════════════════════════════════════

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

class PowerStatusDBHelper(context: Context) :
    SQLiteOpenHelper(context, DB_NAME, null, DB_VERSION) {

    companion object {
        private const val DB_NAME    = "power_status.db"
        private const val DB_VERSION = 1

        const val TABLE_NAME = "power_status_log"

        const val COL_ID          = "local_id"      // local autoincrement PK
        const val COL_USER_ID     = "user_id"
        const val COL_USER_NAME   = "user_name"
        const val COL_CITY        = "city"
        const val COL_DESIGNATION = "designation"
        const val COL_BATTERY     = "battery"
        const val COL_STATUS      = "status"
        const val COL_TIMESTAMP   = "log_timestamp"
        const val COL_IS_POSTED   = "is_posted"      // 0 = pending sync, 1 = synced
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS $TABLE_NAME (
                $COL_ID          INTEGER PRIMARY KEY AUTOINCREMENT,
                $COL_USER_ID     TEXT,
                $COL_USER_NAME   TEXT,
                $COL_CITY        TEXT,
                $COL_DESIGNATION TEXT,
                $COL_BATTERY     REAL,
                $COL_STATUS      TEXT,
                $COL_TIMESTAMP   TEXT,
                $COL_IS_POSTED   INTEGER NOT NULL DEFAULT 0
            )
            """.trimIndent()
        )
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_power_status_posted ON $TABLE_NAME($COL_IS_POSTED)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // No migrations yet — bump DB_VERSION and add ALTER TABLE statements here
        // if new columns are needed in the future.
    }

    /** Insert one heartbeat row. Returns the new local row id, or -1 on failure. */
    fun insertPowerStatus(
        userId: String,
        userName: String,
        city: String,
        designation: String,
        battery: Double,
        status: String,
        timestamp: String
    ): Long {
        val values = ContentValues().apply {
            put(COL_USER_ID, userId)
            put(COL_USER_NAME, userName)
            put(COL_CITY, city)
            put(COL_DESIGNATION, designation)
            put(COL_BATTERY, battery)
            put(COL_STATUS, status)
            put(COL_TIMESTAMP, timestamp)
            put(COL_IS_POSTED, 0)
        }
        return try {
            writableDatabase.insert(TABLE_NAME, null, values)
        } catch (e: Exception) {
            android.util.Log.e("PowerStatusDB", "insert failed: ${e.message}")
            -1L
        }
    }

    /** Rows not yet synced to the server, oldest first. */
    fun getUnpostedRows(limit: Int = 200): List<Map<String, String>> {
        val rows = mutableListOf<Map<String, String>>()
        try {
            readableDatabase.query(
                TABLE_NAME, null,
                "$COL_IS_POSTED = ?", arrayOf("0"),
                null, null,
                "$COL_ID ASC", limit.toString()
            ).use { c ->
                while (c.moveToNext()) {
                    rows.add(
                        mapOf(
                            COL_ID          to c.getLong(c.getColumnIndexOrThrow(COL_ID)).toString(),
                            COL_USER_ID     to (c.getString(c.getColumnIndexOrThrow(COL_USER_ID)) ?: ""),
                            COL_USER_NAME   to (c.getString(c.getColumnIndexOrThrow(COL_USER_NAME)) ?: ""),
                            COL_CITY        to (c.getString(c.getColumnIndexOrThrow(COL_CITY)) ?: ""),
                            COL_DESIGNATION to (c.getString(c.getColumnIndexOrThrow(COL_DESIGNATION)) ?: ""),
                            COL_BATTERY     to c.getDouble(c.getColumnIndexOrThrow(COL_BATTERY)).toString(),
                            COL_STATUS      to (c.getString(c.getColumnIndexOrThrow(COL_STATUS)) ?: ""),
                            COL_TIMESTAMP   to (c.getString(c.getColumnIndexOrThrow(COL_TIMESTAMP)) ?: "")
                        )
                    )
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("PowerStatusDB", "getUnpostedRows failed: ${e.message}")
        }
        return rows
    }

    /** Mark the given local row ids as successfully synced. */
    fun markPosted(ids: List<String>) {
        if (ids.isEmpty()) return
        val db = writableDatabase
        try {
            db.beginTransaction()
            val cv = ContentValues().apply { put(COL_IS_POSTED, 1) }
            for (id in ids) {
                db.update(TABLE_NAME, cv, "$COL_ID = ?", arrayOf(id))
            }
            db.setTransactionSuccessful()
        } catch (e: Exception) {
            android.util.Log.e("PowerStatusDB", "markPosted failed: ${e.message}")
        } finally {
            try { db.endTransaction() } catch (_: Exception) {}
        }
    }

    /** Keep the local table from growing forever — drop old already-synced rows. */
    fun pruneOldPosted(keepLast: Int = 5000) {
        try {
            writableDatabase.execSQL(
                """
                DELETE FROM $TABLE_NAME
                WHERE $COL_IS_POSTED = 1
                  AND $COL_ID NOT IN (
                      SELECT $COL_ID FROM $TABLE_NAME ORDER BY $COL_ID DESC LIMIT $keepLast
                  )
                """.trimIndent()
            )
        } catch (_: Exception) {}
    }
}