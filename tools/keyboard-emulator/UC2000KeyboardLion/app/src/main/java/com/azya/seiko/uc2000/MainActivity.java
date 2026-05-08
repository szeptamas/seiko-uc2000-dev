/*
 * MainActivity.java
 * Keyboard emulator Seiko UC-2000, Lion BIN-upload fork
 */

package com.azya.seiko.uc2000;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.database.Cursor;
import android.content.Intent;
import android.content.SharedPreferences;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.preference.PreferenceManager;
import android.provider.OpenableColumns;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.CompoundButton;
import android.widget.PopupMenu;
import android.widget.TextView;
import android.widget.Toast;
import android.widget.ToggleButton;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Timer;
import java.util.TimerTask;

public class MainActivity extends Activity {
    private static final String PREF_ANTIPHASE = "PREF_ANTIPHASE";
    private static final String PREF_FIRST_RUN = "PREF_FIRST_RUN";
    private static final int REQUEST_OPEN_BIN = 1001;
    private static final int MAX_TRANSFER_SIZE = 2048;
    private static final int PAGE_SIZE = 256;
    private static final int TEST_CODE_A = 0x06;
    private static final int TEST_CODE_B = 0x07;
    private static final int TEST_INTERVAL_MS = 350;

    public final Object[][] keys = {
            {0x31, "1"}, {0x32, "2"}, {0x33, "3"}, {0x34, "4"}, {0x35, "5"},
            {0x36, "6"}, {0x37, "7"}, {0x38, "8"}, {0x39, "9"}, {0x30, "0"},
            {0x71, "q"}, {0x77, "w"}, {0x65, "e"}, {0x72, "r"}, {0x74, "t"},
            {0x79, "y"}, {0x75, "u"}, {0x69, "i"}, {0x6F, "o"}, {0x70, "p"},
            {0x61, "a"}, {0x73, "s"}, {0x64, "d"}, {0x66, "f"}, {0x67, "g"},
            {0x68, "h"}, {0x6A, "j"}, {0x6B, "k"}, {0x6C, "l"}, {0x3F, "?"},
            {0x7A, "z"}, {0x78, "x"}, {0x63, "c"}, {0x76, "v"}, {0x62, "b"},
            {0x6E, "n"}, {0x6D, "m"}, {0x2F, "/"}, {0x2A, "*"}, {0x3E, ">"},
            {0x2B, "+"}, {0x2D, "-"}, {0x7B, "x"}, {0x7D, "/"}, {0x3D, "="},
            {0x2E, "."}, {0x5B, "["}, {0x5D, "]"}, {0x2C, ","}, {0x3A, ":"},
            {0x06, "M-A"}, {0x07, "M-B"}, {0x10, "CAL"}, {0x1F, "CNTU"},
            {0x0A, "UP"}, {0x09, "RGHT"},
            {0x20, "SPACE"}, {0x08, "LEFT"}, {0x0B, "DOWN"}, {0x0D, "RET"}, {0x15, "RST"}
    };

    public final Object[][] keysShift = {
            {0x21, "!"}, {0x2F, "/"}, {0x23, "#"}, {0x24, "$"}, {0x25, "%"},
            {0x26, "&"}, {0x27, "'"}, {0x28, "("}, {0x29, ")"}, {0x5E, "^"},
            {0x51, "Q"}, {0x57, "W"}, {0x45, "E"}, {0x52, "R"}, {0x54, "T"},
            {0x59, "Y"}, {0x55, "U"}, {0x49, "I"}, {0x4F, "O"}, {0x50, "P"},
            {0x41, "A"}, {0x53, "S"}, {0x44, "D"}, {0x46, "F"}, {0x47, "G"},
            {0x48, "H"}, {0x4A, "J"}, {0x4B, "K"}, {0x4C, "L"}, {0x5F, "_"},
            {0x5A, "Z"}, {0x58, "X"}, {0x43, "C"}, {0x56, "V"}, {0x42, "B"},
            {0x4E, "N"}, {0x4D, "M"}, {0x96, "BELL"}, {0x40, "@"}, {0x3C, "<"},
            {0x9B, "UP2"}, {0x9C, "DN2"}, {0x9D, "DRNK"}, {0x9E, "WALK"}, {0x9F, "HAND"},
            {0x97, "SPAD"}, {0x98, "HEAR"}, {0x99, "DIAM"}, {0x9A, "CLUB"}, {0x3B, ";"},
            {0x06, "M-A"}, {0x07, "M-B"}, {0x10, "CAL"}, {0x12, "CNTD"},
            {0x0A, "UP"}, {0x09, "RGHT"},
            {0x20, "SPACE"}, {0x08, "LEFT"}, {0x0B, "DOWN"}, {0x0D, "RET"}, {0x15, "RST"}
    };

    private static final double FREQUENCY = 16386;
    private static final double SAMPLE_RATE = AudioTrack.getNativeOutputSampleRate(AudioManager.STREAM_MUSIC);
    private static final double PERIODS = 8;
    private static final double MULTIPLIER = SAMPLE_RATE / FREQUENCY;
    private static final int WORD_SIZE = 11;
    private static final int SAMPLES_SIZE = (((int) (WORD_SIZE * PERIODS * 2 * MULTIPLIER)) + 1) & ~1;
    private static final int MANUAL_SEND_DELAY_MS = 20;
    private static final int UPLOAD_BYTE_DELAY_MS = 11;
    private static final int UPLOAD_STEP_DELAY_MS = 90;
    private static final int UPLOAD_FRAME_DELAY_MS = 100;

    private int wavePhase = 1;
    private AudioTrack mAudioTrack;
    private Timer mTimer;
    private Timer mTestTimer;
    private boolean mRunAfterUpload = false;
    private boolean mUploadInProgress = false;
    private byte[] mPendingPayload = null;
    private boolean mPendingRunAfterUpload = false;
    private String mPendingFileName = null;
    private TextView mUploadStatusText;
    private boolean mTransmissionTestActive = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        ToggleButton toggle = (ToggleButton) findViewById(R.id.shiftButton);
        toggle.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            @Override
            public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
                if (isChecked) {
                    setButtons(keysShift, keys);
                } else {
                    setButtons(keys, keysShift);
                }
            }
        });

        setButtons(keys, keysShift);
        mUploadStatusText = (TextView) findViewById(R.id.upload_status_text);
        initTransmitter();
        updateUploadStatusIdle();
        findViewById(R.id.transmission_layout).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                onTransmissionAreaClick();
            }
        });
        showHowToUseFirst();
    }

    private void initTransmitter() {
        AudioManager audioManager = (AudioManager) this.getSystemService(Context.AUDIO_SERVICE);
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC), 0);

        mAudioTrack = new AudioTrack(AudioManager.STREAM_MUSIC, (int) SAMPLE_RATE,
                AudioFormat.CHANNEL_OUT_STEREO, AudioFormat.ENCODING_PCM_16BIT,
                SAMPLES_SIZE * (Short.SIZE / 8), AudioTrack.MODE_STATIC);

        mAudioTrack.setAuxEffectSendLevel(0);
        setAntiphase();
    }

    private void showHowToUseFirst() {
        if (PreferenceManager.getDefaultSharedPreferences(this).getBoolean(PREF_FIRST_RUN, true)) {
            showHowToUse();
        }
        SharedPreferences.Editor editor = PreferenceManager.getDefaultSharedPreferences(this).edit();
        editor.putBoolean(PREF_FIRST_RUN, false);
        editor.apply();
    }

    public void FullScreencall() {
        if (Build.VERSION.SDK_INT > 11 && Build.VERSION.SDK_INT < 19) {
            View v = this.getWindow().getDecorView();
            v.setSystemUiVisibility(View.GONE);
        } else if (Build.VERSION.SDK_INT >= 19) {
            View decorView = getWindow().getDecorView();
            int uiOptions = View.SYSTEM_UI_FLAG_HIDE_NAVIGATION |
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY |
                    View.SYSTEM_UI_FLAG_FULLSCREEN |
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE |
                    View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION |
                    View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN;
            decorView.setSystemUiVisibility(uiOptions);
        }
    }

    private void setButtons(Object[][] keyboardKeys, Object[][] keyboardLabels) {
        final ViewGroup viewGroup = (ViewGroup) ((ViewGroup) this.findViewById(android.R.id.content)).getChildAt(0);
        updateButtons(viewGroup, keyboardKeys, 0);
        updateLabels(viewGroup, keyboardLabels, 0);
    }

    private int updateButtons(ViewGroup viewGroup, Object[][] keyboardKeys, int keyIndex) {
        for (int i = 0; i < viewGroup.getChildCount(); i++) {
            View child = viewGroup.getChildAt(i);
            if (child instanceof ViewGroup) {
                keyIndex = updateButtons((ViewGroup) child, keyboardKeys, keyIndex);
            } else if (child.getClass() == Button.class && child.getId() != R.id.menu_main && child.getId() != R.id.send_top) {
                if (keyIndex < keyboardKeys.length) {
                    final int sendValue = (Integer) keyboardKeys[keyIndex][0];
                    ((Button) child).setTag(sendValue);
                    ((Button) child).setText((CharSequence) keyboardKeys[keyIndex][1]);
                    ((Button) child).setOnClickListener(new View.OnClickListener() {
                        @Override
                        public void onClick(View view) {
                            if (mUploadInProgress) {
                                return;
                            }
                            if (mTimer != null) {
                                mTimer.cancel();
                            }
                            stopTransmissionTest();
                            sendByte(sendValue);
                        }
                    });
                    ((Button) child).setOnLongClickListener(new View.OnLongClickListener() {
                        @Override
                        public boolean onLongClick(View view) {
                            if (mUploadInProgress) {
                                return true;
                            }
                            if (mTimer != null) {
                                mTimer.cancel();
                            }
                            stopTransmissionTest();
                            mTimer = new Timer();
                            mTimer.schedule(new PlayAudioTask(sendValue), 500, 500);
                            return true;
                        }
                    });
                    keyIndex++;
                }
            }
        }
        return keyIndex;
    }

    private int updateLabels(ViewGroup viewGroup, Object[][] keyboardKeys, int keyIndex) {
        for (int i = 0; i < viewGroup.getChildCount(); i++) {
            View child = viewGroup.getChildAt(i);
            if (child instanceof ViewGroup) {
                keyIndex = updateLabels((ViewGroup) child, keyboardKeys, keyIndex);
            } else if (child.getClass() == TextView.class) {
                if (keyIndex < keyboardKeys.length) {
                    int keyCode = (Integer) keyboardKeys[keyIndex][0];
                    if ((keyCode < 'A' || keyCode > 'Z') && (keyCode < 'a' || keyCode > 'z') && keys[keyIndex][0] != keysShift[keyIndex][0]) {
                        ((TextView) child).setText((CharSequence) keyboardKeys[keyIndex][1]);
                    }
                    keyIndex++;
                }
            }
        }
        return keyIndex;
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (mTimer != null) {
            mTimer.cancel();
        }
        stopTransmissionTest();
        mAudioTrack.release();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            FullScreencall();
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);

        if (requestCode != REQUEST_OPEN_BIN || resultCode != RESULT_OK || data == null) {
            return;
        }

        Uri uri = data.getData();
        if (uri == null) {
            showToast(R.string.file_open_failed);
            return;
        }

        try {
            byte[] payload = readBytes(uri);
            if (payload.length > MAX_TRANSFER_SIZE) {
                showToast(R.string.upload_file_too_large);
                return;
            }
            mPendingPayload = payload;
            mPendingRunAfterUpload = mRunAfterUpload;
            mPendingFileName = resolveDisplayName(uri);
            updateUploadStatusReady(mPendingFileName, mPendingRunAfterUpload);
            showToast(mRunAfterUpload ? R.string.upload_ready_run : R.string.upload_ready);
        } catch (IOException ex) {
            Log.d("readBytes() failed " + ex);
            showToast(R.string.file_open_failed);
        }
    }

    private void onTransmissionAreaClick() {
        if (mUploadInProgress) {
            return;
        }

        stopTransmissionTest();

        if (mPendingPayload == null) {
            showToast(R.string.no_pending_bin);
            return;
        }

        byte[] payload = mPendingPayload;
        boolean runAfterUpload = mPendingRunAfterUpload;
        String fileName = mPendingFileName;
        mPendingPayload = null;
        mPendingRunAfterUpload = false;
        mPendingFileName = null;
        startUpload(payload, runAfterUpload, fileName);
    }

    private synchronized void sendByte(int sendByte) {
        sendByte(sendByte, MANUAL_SEND_DELAY_MS);
    }

    private synchronized void sendByte(int sendByte, int pauseMs) {
        Log.d("sendByte() " + sendByte);
        int parity = sendByte ^ (sendByte >> 4);
        parity ^= parity >> 2;
        parity ^= parity >> 1;
        parity &= 0x01;

        int[] wordBuffer = new int[WORD_SIZE];
        wordBuffer[0] = 1;
        for (int i = 1; i < 9; i++) {
            wordBuffer[i] = ~(sendByte >> (i - 1)) & 0x01;
        }
        wordBuffer[9] = ~parity & 0x01;
        wordBuffer[10] = 0;

        short[] samples = new short[SAMPLES_SIZE];
        for (int i = 0; i < SAMPLES_SIZE; i += 2) {
            if (wordBuffer[(int) (i / MULTIPLIER / (PERIODS * 2)) % WORD_SIZE] == 1) {
                samples[i] = (short) (wavePhase * (Math.sin(i * Math.PI / MULTIPLIER) * Short.MAX_VALUE));
                samples[i + 1] = (short) -samples[i];
            } else {
                samples[i] = 0;
                samples[i + 1] = 0;
            }
        }

        mAudioTrack.write(samples, 0, SAMPLES_SIZE);
        mAudioTrack.play();
        try {
            Thread.sleep(pauseMs);
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
        }
        mAudioTrack.stop();
        mAudioTrack.reloadStaticData();
    }

    private class PlayAudioTask extends TimerTask {
        private final int sendByte;

        PlayAudioTask(int sendByte) {
            this.sendByte = sendByte;
        }

        @Override
        public void run() {
            MainActivity.this.sendByte(sendByte);
        }
    }

    private void popup(View view) {
        PopupMenu menuMain = new PopupMenu(this, view);
        menuMain.inflate(R.menu.menu_main);
        MenuItem item = menuMain.getMenu().findItem(R.id.antiphase);
        item.setChecked(PreferenceManager.getDefaultSharedPreferences(this).getBoolean(PREF_ANTIPHASE, false));
        menuMain.getMenu().findItem(R.id.transmission_test_start).setVisible(!mTransmissionTestActive);
        menuMain.getMenu().findItem(R.id.transmission_test_stop).setVisible(mTransmissionTestActive);
        menuMain.setOnMenuItemClickListener(new PopupMenu.OnMenuItemClickListener() {
            @Override
            public boolean onMenuItemClick(MenuItem item) {
                switch (item.getItemId()) {
                    case R.id.antiphase:
                        setAntiphase(!item.isChecked());
                        return true;
                    case R.id.how_to_use:
                        showHowToUse();
                        return true;
                    case R.id.upload_bin:
                        openBinPicker(false);
                        return true;
                    case R.id.upload_bin_run:
                        openBinPicker(true);
                        return true;
                    case R.id.transmission_test_start:
                        startTransmissionTest();
                        return true;
                    case R.id.transmission_test_stop:
                        stopTransmissionTest();
                        refreshStatusAfterTest();
                        return true;
                    default:
                        return true;
                }
            }
        });
        menuMain.show();
    }

    public void onMenuClick(View view) {
        popup(view);
    }

    public void onSendButtonClick(View view) {
        onTransmissionAreaClick();
    }

    private void showHowToUse() {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setMessage(R.string.help).setNegativeButton(android.R.string.ok, null).show();
    }

    private void setAntiphase(boolean antiphase) {
        SharedPreferences.Editor editor = PreferenceManager.getDefaultSharedPreferences(this).edit();
        editor.putBoolean(PREF_ANTIPHASE, antiphase);
        editor.apply();
        wavePhase = antiphase ? 1 : -1;
    }

    private void setAntiphase() {
        boolean antiphase = PreferenceManager.getDefaultSharedPreferences(this).getBoolean(PREF_ANTIPHASE, false);
        wavePhase = antiphase ? 1 : -1;
    }

    private void openBinPicker(boolean runAfterUpload) {
        if (mUploadInProgress) {
            showToast(R.string.upload_in_progress);
            return;
        }

        stopTransmissionTest();
        refreshStatusAfterTest();
        mRunAfterUpload = runAfterUpload;
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("*/*");
        startActivityForResult(intent, REQUEST_OPEN_BIN);
    }

    private void startTransmissionTest() {
        if (mUploadInProgress || mTransmissionTestActive) {
            return;
        }

        stopTransmissionTest();
        mTransmissionTestActive = true;
        updateUploadStatusTest();
        mTestTimer = new Timer();
        mTestTimer.scheduleAtFixedRate(new TimerTask() {
            private boolean sendA = true;

            @Override
            public void run() {
                MainActivity.this.sendByte(sendA ? TEST_CODE_A : TEST_CODE_B);
                sendA = !sendA;
            }
        }, 0, TEST_INTERVAL_MS);
    }

    private void stopTransmissionTest() {
        if (mTestTimer != null) {
            mTestTimer.cancel();
            mTestTimer = null;
        }
        mTransmissionTestActive = false;
    }

    private void refreshStatusAfterTest() {
        if (mPendingPayload != null && mPendingFileName != null) {
            updateUploadStatusReady(mPendingFileName, mPendingRunAfterUpload);
        } else {
            updateUploadStatusIdle();
        }
    }

    private String resolveDisplayName(Uri uri) {
        Cursor cursor = null;
        try {
            cursor = getContentResolver().query(uri, null, null, null, null);
            if (cursor != null && cursor.moveToFirst()) {
                int index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                if (index >= 0) {
                    String name = cursor.getString(index);
                    if (name != null && !name.isEmpty()) {
                        return name;
                    }
                }
            }
        } catch (Exception ex) {
            Log.d("resolveDisplayName() failed " + ex);
        } finally {
            if (cursor != null) {
                cursor.close();
            }
        }

        String lastSegment = uri.getLastPathSegment();
        if (lastSegment == null || lastSegment.isEmpty()) {
            return "selected.bin";
        }
        int slash = lastSegment.lastIndexOf('/');
        return slash >= 0 ? lastSegment.substring(slash + 1) : lastSegment;
    }

    private byte[] readBytes(Uri uri) throws IOException {
        InputStream inputStream = getContentResolver().openInputStream(uri);
        if (inputStream == null) {
            throw new IOException("Input stream is null");
        }

        ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
        byte[] buffer = new byte[4096];
        int read;

        try {
            while ((read = inputStream.read(buffer)) != -1) {
                outputStream.write(buffer, 0, read);
            }
        } finally {
            inputStream.close();
        }

        return outputStream.toByteArray();
    }

    private void startUpload(final byte[] payload, final boolean runAfterUpload, final String fileName) {
        mUploadInProgress = true;
        updateUploadStatusSending(fileName);

        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    uploadBinary(payload, runAfterUpload);
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            updateUploadStatusComplete(fileName, runAfterUpload);
                            showToast(runAfterUpload ? R.string.upload_complete_run : R.string.upload_complete);
                        }
                    });
                } catch (InterruptedException ex) {
                    Thread.currentThread().interrupt();
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            updateUploadStatusFailed(fileName);
                            showToast(R.string.upload_failed);
                        }
                    });
                } finally {
                    mUploadInProgress = false;
                }
            }
        }).start();
    }

    private void uploadBinary(byte[] data, boolean runAfterUpload) throws InterruptedException {
        int totalPages = (data.length + PAGE_SIZE - 1) / PAGE_SIZE;
        if (totalPages < 1) {
            totalPages = 1;
        }
        if (totalPages > 8) {
            totalPages = 8;
        }

        sendByte(0x1A, UPLOAD_FRAME_DELAY_MS);
        sendByte(0x18, UPLOAD_FRAME_DELAY_MS);
        sendByte(0x01, UPLOAD_FRAME_DELAY_MS);

        for (int page = 0; page < totalPages; page++) {
            sendByte(0x04, UPLOAD_STEP_DELAY_MS);
            sendByte(page, UPLOAD_STEP_DELAY_MS);
            sendByte(0x00, UPLOAD_STEP_DELAY_MS);

            for (int i = 0; i < PAGE_SIZE; i++) {
                int pos = page * 256 + i;
                if (pos < data.length) {
                    sendByte(data[pos] & 0xFF, UPLOAD_BYTE_DELAY_MS);
                } else {
                    sendByte(0x00, UPLOAD_BYTE_DELAY_MS);
                }
            }

            Thread.sleep(UPLOAD_FRAME_DELAY_MS);
        }

        sendByte(0x11, UPLOAD_FRAME_DELAY_MS);
        sendByte(0x18, UPLOAD_FRAME_DELAY_MS);

        if (runAfterUpload) {
            sendByte(0x02, UPLOAD_FRAME_DELAY_MS);
        }
    }

    private void updateUploadStatusIdle() {
        if (mUploadStatusText != null) {
            mUploadStatusText.setText(R.string.upload_status_idle);
        }
    }

    private void updateUploadStatusReady(String fileName, boolean runAfterUpload) {
        if (mUploadStatusText != null) {
            mUploadStatusText.setText(getString(runAfterUpload ? R.string.upload_status_ready_run : R.string.upload_status_ready, fileName));
        }
    }

    private void updateUploadStatusSending(String fileName) {
        if (mUploadStatusText != null) {
            mUploadStatusText.setText(getString(R.string.upload_status_sending, fileName));
        }
    }

    private void updateUploadStatusComplete(String fileName, boolean runAfterUpload) {
        if (mUploadStatusText != null) {
            mUploadStatusText.setText(getString(runAfterUpload ? R.string.upload_status_complete_run : R.string.upload_status_complete, fileName));
        }
    }

    private void updateUploadStatusTest() {
        if (mUploadStatusText != null) {
            mUploadStatusText.setText(R.string.upload_status_test);
        }
    }

    private void updateUploadStatusFailed(String fileName) {
        if (mUploadStatusText != null) {
            mUploadStatusText.setText(getString(R.string.upload_status_failed, fileName));
        }
    }

    private void showToast(int messageId) {
        Toast.makeText(this, messageId, Toast.LENGTH_SHORT).show();
    }
}

