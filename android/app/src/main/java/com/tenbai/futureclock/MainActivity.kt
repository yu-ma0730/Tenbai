package com.tenbai.futureclock

import android.app.DatePickerDialog
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import androidx.appcompat.app.AppCompatActivity
import androidx.cardview.widget.CardView
import androidx.core.content.ContextCompat
import com.tenbai.futureclock.databinding.ActivityMainBinding
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Calendar

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private val handler = Handler(Looper.getMainLooper())
    private var selectedDate: LocalDate? = null

    private val dateFormatter = DateTimeFormatter.ofPattern("yyyy年M月d日 (E)")
    private val timeFormatter = DateTimeFormatter.ofPattern("HH:mm:ss")

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
                binding.tvSelectedDate.text = selectedDate!!.format(
                    DateTimeFormatter.ofPattern("yyyy年M月d日 (E)")
                )
                binding.cardCountdown.visibility = View.VISIBLE
                binding.cardStatus.visibility = View.VISIBLE
                updateClock()
            },
            today.get(Calendar.YEAR),
            today.get(Calendar.MONTH),
            today.get(Calendar.DAY_OF_MONTH)
        ).also { dialog ->
            // 今日以降のみ選択可能
            dialog.datePicker.minDate = today.timeInMillis
            dialog.show()
        }
    }

    private fun updateCountdown(target: LocalDate, now: LocalDateTime) {
        val targetDateTime = target.atStartOfDay()
        val totalSeconds = ChronoUnit.SECONDS.between(now, targetDateTime)

        if (totalSeconds <= 0) {
            // 当日または過去
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

        // 今日から目標日までの日数（カレンダー日）
        val calendarDays = ChronoUnit.DAYS.between(now.toLocalDate(), target)
        updateAbsenceStatus(calendarDays, target)
    }

    private fun updateAbsenceStatus(daysUntil: Long, target: LocalDate) {
        val deadlineDate = target.minusDays(10)
        val deadlineStr = deadlineDate.format(DateTimeFormatter.ofPattern("M月d日"))

        when {
            daysUntil >= 10 -> {
                // 10日以上前 → 欠勤登録OK
                setStatusCard(
                    bgColor = R.color.status_ok_bg,
                    labelText = "欠勤種別",
                    typeText = "✓ 欠勤登録",
                    typeColor = R.color.accent_green,
                    descText = "10日前以上のため事前登録が可能です",
                    deadlineText = "登録締切: $deadlineStr（今日を含めてあと${daysUntil - 10 + 1}日の余裕）"
                )
            }
            daysUntil in 1..9 -> {
                // 1〜9日前 → 当日欠勤扱い
                setStatusCard(
                    bgColor = R.color.status_ng_bg,
                    labelText = "欠勤種別",
                    typeText = "⚠ 当日欠勤",
                    typeColor = R.color.accent_red,
                    descText = "登録締切（$deadlineStr）を過ぎています",
                    deadlineText = "欠勤登録できる期間は終了しています"
                )
            }
            else -> {
                // 当日
                showTodayAbsence()
            }
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
        bgColor: Int,
        labelText: String,
        typeText: String,
        typeColor: Int,
        descText: String,
        deadlineText: String
    ) {
        val card = binding.cardStatus as CardView
        card.setCardBackgroundColor(ContextCompat.getColor(this, bgColor))
        binding.tvStatusLabel.text = labelText
        binding.tvStatusType.text = typeText
        binding.tvStatusType.setTextColor(ContextCompat.getColor(this, typeColor))
        binding.tvStatusDesc.text = descText
        binding.tvDeadline.text = deadlineText
    }
}
