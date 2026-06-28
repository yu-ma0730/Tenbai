package com.tenbai.futureclock

import android.Manifest
import android.app.DatePickerDialog
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.inputmethod.InputMethodManager
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.cardview.widget.CardView
import androidx.core.content.ContextCompat
import com.tenbai.futureclock.databinding.ActivityMainBinding
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Calendar

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private val handler = Handler(Looper.getMainLooper())
    private var selectedDate: LocalDate? = null

    private val dateFormatter = DateTimeFormatter.ofPattern("yyyy年M月d日 (E)")
    private val timeFormatter = DateTimeFormatter.ofPattern("HH:mm:ss")

    private val notifPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) scheduleAlert() else showAlertStatus("通知の許可が必要です")
    }

    private val clockRunnable = object : Runnable {
        override fun run() {
            updateClock()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.btnSelectDate.setOnClickListener { showDatePicker() }
        binding.btnSetAlert.setOnClickListener { onSetAlertClicked() }
    }

    override fun onResume() {
        super.onResume()
        handler.post(clockRunnable)
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacks(clockRunnable)
    }

    private fun updateClock() {
        val now = LocalDateTime.now()
        binding.tvCurrentDate.text = now.format(dateFormatter)
        binding.tvCurrentTime.text = now.format(timeFormatter)
        selectedDate?.let { updateCountdown(it, now) }
    }

    private fun showDatePicker() {
        val today = Calendar.getInstance()
        DatePickerDialog(
            this,
            { _, year, month, day ->
                selectedDate = LocalDate.of(year, month + 1, day)
                binding.tvSelectedDate.text = selectedDate!!.format(dateFormatter)
                binding.cardCountdown.visibility = View.VISIBLE
                binding.cardStatus.visibility = View.VISIBLE
                binding.btnSetAlert.visibility = View.VISIBLE
                binding.tvAlertStatus.visibility = View.GONE
                AlarmHelper.cancel(this)
                updateClock()
            },
            today.get(Calendar.YEAR),
            today.get(Calendar.MONTH),
            today.get(Calendar.DAY_OF_MONTH)
        ).also { dialog ->
            dialog.datePicker.minDate = today.timeInMillis
            dialog.show()
        }
    }

    private fun getThreshold(): Int =
        binding.etDaysThreshold.text?.toString()?.toIntOrNull()?.coerceAtLeast(1) ?: 10

    private fun getAlertDays(): Int =
        binding.etAlertDays.text?.toString()?.toIntOrNull()?.coerceAtLeast(1) ?: 11

    private fun updateCountdown(target: LocalDate, now: LocalDateTime) {
        val targetDateTime = target.atStartOfDay()
        val totalSeconds = ChronoUnit.SECONDS.between(now, targetDateTime)

        if (totalSeconds <= 0) {
            binding.tvDays.text = "0"
            binding.tvHours.text = "00"
            binding.tvMinutes.text = "00"
            binding.tvSeconds.text = "00"
            showTodayAbsence()
            return
        }

        val days = totalSeconds / 86400
        val hours = (totalSeconds % 86400) / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60

        binding.tvDays.text = days.toString()
        binding.tvHours.text = hours.toString().padStart(2, '0')
        binding.tvMinutes.text = minutes.toString().padStart(2, '0')
        binding.tvSeconds.text = seconds.toString().padStart(2, '0')

        val calendarDays = ChronoUnit.DAYS.between(now.toLocalDate(), target)
        updateAbsenceStatus(calendarDays, target)
    }

    private fun updateAbsenceStatus(daysUntil: Long, target: LocalDate) {
        val threshold = getThreshold().toLong()
        val deadlineDate = target.minusDays(threshold)
        val deadlineStr = deadlineDate.format(DateTimeFormatter.ofPattern("M月d日"))

        when {
            daysUntil >= threshold -> {
                setStatusCard(
                    bgColor = R.color.status_ok_bg,
                    labelText = "欠勤種別",
                    typeText = "✓ 欠勤登録",
                    typeColor = R.color.accent_green,
                    descText = "${threshold}日前以上のため事前登録が可能です",
                    deadlineText = "登録締切: $deadlineStr（あと${daysUntil - threshold + 1}日の余裕）"
                )
            }
            daysUntil in 1 until threshold -> {
                setStatusCard(
                    bgColor = R.color.status_ng_bg,
                    labelText = "欠勤種別",
                    typeText = "⚠ 当日欠勤",
                    typeColor = R.color.accent_red,
                    descText = "登録締切（$deadlineStr）を過ぎています",
                    deadlineText = "欠勤登録できる期間は終了しています"
                )
            }
            else -> showTodayAbsence()
        }
    }

    private fun showTodayAbsence() {
        setStatusCard(
            bgColor = R.color.status_today_bg,
            labelText = "欠勤種別",
            typeText = "！当日欠勤",
            typeColor = R.color.accent_orange,
            descText = "本日が欠勤日です",
            deadlineText = "会社の規定に従い連絡してください"
        )
    }

    private fun setStatusCard(
        bgColor: Int, labelText: String, typeText: String,
        typeColor: Int, descText: String, deadlineText: String
    ) {
        val card = binding.cardStatus as CardView
        card.setCardBackgroundColor(ContextCompat.getColor(this, bgColor))
        binding.tvStatusLabel.text = labelText
        binding.tvStatusType.text = typeText
        binding.tvStatusType.setTextColor(ContextCompat.getColor(this, typeColor))
        binding.tvStatusDesc.text = descText
        binding.tvDeadline.text = deadlineText
    }

    // ---- アラート関連 ----

    private fun onSetAlertClicked() {
        hideKeyboard()
        if (selectedDate == null) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                notifPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                return
            }
        }
        scheduleAlert()
    }

    private fun scheduleAlert() {
        val target = selectedDate ?: return
        val alertDays = getAlertDays()
        val threshold = getThreshold()

        // アラートを鳴らす日 = 欠勤日の alertDays 日前 の午前9時
        val alertDate = target.minusDays(alertDays.toLong())
        val alertDateTime = alertDate.atTime(9, 0, 0)
        val triggerMs = alertDateTime.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()

        if (triggerMs <= System.currentTimeMillis()) {
            showAlertStatus("⚠ アラート日時（${alertDate.format(DateTimeFormatter.ofPattern("M月d日"))} 09:00）はすでに過ぎています")
            return
        }

        val daysLeft = ChronoUnit.DAYS.between(alertDate, target).toInt()
        val targetDateStr = target.format(DateTimeFormatter.ofPattern("M月d日"))

        AlarmHelper.schedule(this, triggerMs, threshold, targetDateStr, daysLeft)

        // 再起動後の復元用に保存
        getSharedPreferences("futureclock", Context.MODE_PRIVATE).edit()
            .putLong("alert_time_ms", triggerMs)
            .putInt("threshold", threshold)
            .putString("target_date", targetDateStr)
            .putInt("days_left", daysLeft)
            .apply()

        val alertDateStr = alertDate.format(DateTimeFormatter.ofPattern("M月d日"))
        showAlertStatus("🔔 アラートをセットしました\n${alertDateStr} 09:00 に通知します")
    }

    private fun showAlertStatus(msg: String) {
        binding.tvAlertStatus.text = msg
        binding.tvAlertStatus.visibility = View.VISIBLE
    }

    private fun hideKeyboard() {
        val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
        currentFocus?.let { imm.hideSoftInputFromWindow(it.windowToken, 0) }
    }
}
