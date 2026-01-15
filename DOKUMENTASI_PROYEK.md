# Dokumentasi Teknis Aplikasi Pengingat Tidur

Dokumen ini disusun untuk membantu penyusunan laporan proyek berdasarkan persyaratan yang diminta.

## 1. Arsitektur dan Halaman (Minimal 4 Screen)

Aplikasi ini memiliki 4 layar utama dengan navigasi yang terintegrasi:

1.  **Splash Screen** (`splash_screen.dart`)
    - **Fungsi**: Layar pembuka saat aplikasi dijalankan.
    - **Implementasi**: Menampilkan logo dengan animasi _fade-in_ dan _scale_, secara otomatis berpindah ke halaman utama setelah 3 detik.
2.  **Home Screen** (`home_screen.dart`)
    - **Fungsi**: Dashboard utama untuk pengguna.
    - **Implementasi**: Tempat pengguna menyetel waktu tidur, melihat sisa waktu (countdown), dan mengakses riwayat. Menggunakan animasi bulan bergerak (_floating animation_) untuk estetika.
3.  **Alarm Overlay Screen** (`main.dart` - `OverlayAlarmWidget`)
    - **Fungsi**: Layar "Mode Tidur" yang muncul menutupi seluruh sistem Android saat alarm berbunyi.
    - **Implementasi**: Menggunakan `FlutterOverlayWindow` untuk menggambar UI di atas aplikasi lain. Fitur ini memaksa pengguna berhenti menggunakan HP.
4.  **History Screen** (`history_screen.dart`)
    - **Fungsi**: Menampilkan daftar riwayat kepatuhan tidur pengguna.
    - **Implementasi**: Mengambil data dari database SQLite lokal dan menampilkannya dalam _ListView_.

## 2. Fungsionalitas Utama (Minimal 3 Fitur Dinamis)

Fitur-fitur dinamis yang berjalan secara _real-time_:

1.  **Hybrid Alarm Scheduling System**:
    - Menggabungkan _Standard Alarm_ dan _Android Alarm Manager Plus_ untuk memastikan alarm tetap berjalan akurat meskipun aplikasi ditutup total atau HP terkunci (memanfaatkan _Doze Mode bypass_).
2.  **Persistent Sleep Mode Overlay**:
    - Fitur keamanan digital yang memblokir akses layar selama 1 jam (atau waktu yang ditentukan) setelah alarm berbunyi. Overlay ini memiliki logika proteksi (tidak bisa ditutup sembarangan) dan hanya mengizinkan pematian suara.
3.  **Automatic Activity Logging**:
    - Sistem pencatatan otomatis yang berjalan di latar belakang. Saat pengguna mematikan suara atau saat sesi tidur selesai, aplikasi secara otomatis menulis log kejadian tersebut ke database tanpa input manual.

## 3. Pengelolaan Data (SQLite Database)

Aplikasi menggunakan penyimpanan data persisten lokal menggunakan library **`sqflite`**:

- **Implementasi**: Class `DatabaseService` (Singleton pattern).
- **Struktur Data**: Tabel `sleep_history` dengan kolom `id`, `timestamp` (Waktu kejadian), dan `status` (Jenis aktivitas: "Suara Matikan" atau "Sesi Selesai").
- **Penggunaan**: Data disimpan secara permanen di memori perangkat dan tidak hilang meskipun aplikasi di-uninstall atau HP direstart.

## 4. Manajemen State dan Lifecycle

Aplikasi menangani siklus hidup (_lifecycle_) dan perubahan state dengan teknik berikut:

- **App Lifecycle**: Menggunakan `WidgetsBindingObserver` pada `main.dart` (`didChangeAppLifecycleState`) untuk mendeteksi saat aplikasi kembali aktif (`resumed`) guna memeriksa sinkronisasi alarm yang mungkin terlewat.
- **View Recycling State**: Pada `OverlayAlarmWidget`, menggunakan pola _Listener_ (`FlutterOverlayWindow.overlayListener`) untuk menangani masalah daur ulang _View_ Android. Saat view lama digunakan kembali, sinyal `RESET` dikirim untuk memastikan UI (tombol/timer) kembali ke keadaan awal.
- **Stateful Widgets**: Penggunaan `setState` yang efisien untuk memperbarui UI penghitung mundur (_countdown_) dan status tombol secara real-time.

## 5. Desain Antarmuka (UI/UX)

Desain berfokus pada tema "Malam" untuk kenyamanan mata (_Sleep Hygiene_):

- **Konsistensi Tema**: Menggunakan `AppTheme` class terpusat dengan palet warna gelap (_Dark Mode_), gradien ungu-biru, dan font _Google Fonts_ (Poppins).
- **Komponen Standar**: Menggunakan widget Material Design standar seperti `Card` untuk list riwayat, `FloatingActionButton`, `Switch`, dan `Dialog` yang dikustomisasi.
- **Feedback Visual**: Memberikan umpan balik instan kepada pengguna (contoh: _SnackBar_ saat alarm diset, indikator loading, dan animasi transisi halaman).

## 6. Penanganan Error (Exception Handling)

Aplikasi dibuat _robust_ (tahan banting) dengan penanganan error berlapis:

- **Permission Handling**: Sebelum menampilkan overlay, aplikasi mengecek izin terlebih dahulu. Jika ditolak, aplikasi melakukan _fallback_ dengan menampilkan UI dalam aplikasi (`Navigator.push`) agar tidak _crash_.
- **Fail-safe Mechanism**: Menambahkan mekanisme _fallback_ `SystemNavigator.pop()` dan `exit(0)` pada timer overlay untuk memastikan overlay benar-benar tertutup jika metode penutupan utama gagal karena restriksi sistem Android.
- **Try-Catch Blocks**: Seluruh operasi yang berisiko (inisialisasi database, pemutaran audio, akses service native) dibungkus dalam blok `try-catch` untuk mencegah aplikasi _force close_ saat terjadi kesalahan tak terduga.
