package com.example.imtbf.presentation.views;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RectF;
import android.util.AttributeSet;
import android.view.View;

import com.example.imtbf.data.models.NetworkStats;

import java.util.ArrayList;
import java.util.List;

/**
 * Custom view to display network speed in a graph
 */
public class NetworkSpeedGaugeView extends View {

    private static final int MAX_POINTS = 60; // Show 60 seconds of data
    private static final float DEFAULT_MAX_SPEED = 100 * 1024; // 100 KB/s initial max

    private final Paint downloadPaint = new Paint();
    private final Paint uploadPaint = new Paint();
    private final Paint gridPaint = new Paint();
    private final Paint textPaint = new Paint();
    private final Path downloadPath = new Path();
    private final Path uploadPath = new Path();

    private final List<Float> downloadSpeeds = new ArrayList<>();
    private final List<Float> uploadSpeeds = new ArrayList<>();
    private float maxSpeed = DEFAULT_MAX_SPEED; // Bytes per second

    public NetworkSpeedGaugeView(Context context) {
        super(context);
        init();
    }

    public NetworkSpeedGaugeView(Context context, AttributeSet attrs) {
        super(context, attrs);
        init();
    }

    public NetworkSpeedGaugeView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init();
    }

    private void init() {
        // Initialize paints
        downloadPaint.setColor(Color.rgb(76, 175, 80)); // Green
        downloadPaint.setStyle(Paint.Style.FILL_AND_STROKE);
        downloadPaint.setStrokeWidth(2f);
        downloadPaint.setAntiAlias(true);

        uploadPaint.setColor(Color.rgb(33, 150, 243)); // Blue
        uploadPaint.setStyle(Paint.Style.FILL_AND_STROKE);
        uploadPaint.setStrokeWidth(2f);
        uploadPaint.setAntiAlias(true);

        gridPaint.setColor(Color.LTGRAY);
        gridPaint.setStyle(Paint.Style.STROKE);
        gridPaint.setStrokeWidth(1f);
        gridPaint.setPathEffect(new android.graphics.DashPathEffect(new float[]{5, 5}, 0));
        gridPaint.setAntiAlias(true);

        textPaint.setColor(Color.DKGRAY);
        textPaint.setTextSize(16f);
        textPaint.setAntiAlias(true);

        // Initialize with zero values
        for (int i = 0; i < MAX_POINTS; i++) {
            downloadSpeeds.add(0f);
            uploadSpeeds.add(0f);
        }
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);

        int width = getWidth();
        int height = getHeight();
        int padding = 20;

        float graphWidth = width - 2 * padding;
        float graphHeight = height - 2 * padding;

        // Draw grid
        for (int i = 1; i <= 3; i++) {
            float y = padding + graphHeight * (1 - i / 3f);
            canvas.drawLine(padding, y, width - padding, y, gridPaint);

            // Label the grid line with speed
            String speedLabel = formatSpeed(maxSpeed * i / 3);
            canvas.drawText(speedLabel, padding + 5, y - 5, textPaint);
        }

        // Draw vertical grid line every 10 seconds
        float pointSpacing = graphWidth / (MAX_POINTS - 1);
        for (int i = 0; i < MAX_POINTS; i += 10) {
            float x = padding + i * pointSpacing;
            canvas.drawLine(x, padding, x, height - padding, gridPaint);
        }

        // Draw the speed graphs
        drawSpeedGraph(canvas, downloadSpeeds, downloadPaint, padding, graphWidth, graphHeight);
        drawSpeedGraph(canvas, uploadSpeeds, uploadPaint, padding, graphWidth, graphHeight);

        // Draw legend
        float legendX = width - 150;
        float legendY = padding + 15;

        // Download legend
        canvas.drawRect(legendX, legendY - 10, legendX + 20, legendY + 5, downloadPaint);
        canvas.drawText("Download", legendX + 25, legendY, textPaint);

        // Upload legend
        legendY += 25;
        canvas.drawRect(legendX, legendY - 10, legendX + 20, legendY + 5, uploadPaint);
        canvas.drawText("Upload", legendX + 25, legendY, textPaint);
    }

    /**
     * Draw a speed graph path
     */
    private void drawSpeedGraph(Canvas canvas, List<Float> speeds, Paint paint,
                                int padding, float graphWidth, float graphHeight) {
        Path path = new Path();
        boolean pathStarted = false;

        float pointSpacing = graphWidth / (MAX_POINTS - 1);

        for (int i = 0; i < speeds.size(); i++) {
            float x = padding + i * pointSpacing;
            float speedRatio = Math.min(speeds.get(i) / maxSpeed, 1.0f);
            float y = padding + graphHeight * (1 - speedRatio);

            if (!pathStarted) {
                path.moveTo(x, y);
                pathStarted = true;
            } else {
                path.lineTo(x, y);
            }
        }

        // Add bottom part to create closed shape
        path.lineTo(padding + graphWidth, padding + graphHeight);
        path.lineTo(padding, padding + graphHeight);
        path.close();

        canvas.drawPath(path, paint);
    }

    /**
     * Add a new network stats point to the graph
     * @param stats Network stats
     */
    public void addNetworkStats(NetworkStats stats) {
        if (stats == null) return;

        // Calculate new max speed if needed (with some headroom)
        float currentMaxSpeed = Math.max(stats.getDownloadSpeed(), stats.getUploadSpeed());
        if (currentMaxSpeed > maxSpeed * 0.8f) {
            // If we're at 80% of max, increase the max by 50%
            maxSpeed = currentMaxSpeed * 1.5f;
        }

        // Add new values
        downloadSpeeds.add(stats.getDownloadSpeed());
        uploadSpeeds.add(stats.getUploadSpeed());

        // Remove oldest values
        if (downloadSpeeds.size() > MAX_POINTS) {
            downloadSpeeds.remove(0);
        }
        if (uploadSpeeds.size() > MAX_POINTS) {
            uploadSpeeds.remove(0);
        }

        // Redraw the view
        invalidate();
    }

    /**
     * Reset the graph data
     */
    public void reset() {
        downloadSpeeds.clear();
        uploadSpeeds.clear();
        maxSpeed = DEFAULT_MAX_SPEED;

        // Initialize with zero values
        for (int i = 0; i < MAX_POINTS; i++) {
            downloadSpeeds.add(0f);
            uploadSpeeds.add(0f);
        }

        invalidate();
    }

    /**
     * Format speed for display
     * @param bytesPerSecond Speed in bytes per second
     * @return Formatted string
     */
    private String formatSpeed(float bytesPerSecond) {
        if (bytesPerSecond < 1024) {
            return Math.round(bytesPerSecond) + " B/s";
        } else if (bytesPerSecond < 1024 * 1024) {
            return Math.round(bytesPerSecond / 1024) + " KB/s";
        } else {
            return String.format("%.1f MB/s", bytesPerSecond / (1024 * 1024));
        }
    }
}