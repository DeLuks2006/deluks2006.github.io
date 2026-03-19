<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="3.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" version="1.0" encoding="UTF-8" indent="yes" />
  <xsl:template match="/">
    <html xmlns="http://www.w3.org/1999/xhtml">
      <head>
        <title><xsl:value-of select="/rss/channel/title" /> - RSS Feed</title>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1" />
        <style type="text/css">
          body {
          font-family: 'Inter', -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Oxygen,
          Ubuntu, Cantarell, Fira Sans, Droid Sans, Helvetica Neue, sans-serif;
          margin: 0 auto;
          margin-top: 6em;
          background-color: #fff;
          font-size: 0.9375rem;
          line-height: 1.45;
          color: rgba(0, 0, 0, 0.85);
          max-width: 22.5rem;
          }
          .header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          }
          .divider {
          margin: 2em 0;
          width: 100%;
          height: 1px;
          background: repeating-linear-gradient(
          to right,
          currentColor 0,
          currentColor 3px,
          transparent 3px,
          transparent 6px
          );
          opacity: 0.12;
          }
          .title {
          font-size: 1.0625rem;
          font-weight: 600;
          }
          .description {
          margin-bottom: 1.45em;
          }
          .footer {
          font-size: 0.8125rem;
          opacity: 0.475;
          }
          @media (prefers-color-scheme: dark) {
          body {
          background-color: #1c1c1c;
          color: #fff;
          }
          }
        </style>
      </head>
      <body>
        <div class="channel-meta">
          <div class="header">
            <span class="title">
              <xsl:value-of select="/rss/channel/title" />
            </span>
            <span class="rss-icon">
              <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24">
                <path fill="#F18F48"
                  d="M5 21q-.825 0-1.412-.587T3 19t.588-1.412T5 17t1.413.588T7 19t-.587 1.413T5 21m13.5 0q-.65 0-1.088-.475T16.9 19.4q-.275-2.425-1.312-4.537T12.9 11.1T9.138 8.413T4.6 7.1q-.65-.075-1.125-.512T3 5.5t.45-1.062t1.075-.363q3.075.275 5.763 1.563t4.737 3.337t3.338 4.738t1.562 5.762q.05.625-.363 1.075T18.5 21m-6 0q-.625 0-1.075-.437T10.85 19.5q-.225-1.225-.787-2.262T8.65 15.35t-1.888-1.412T4.5 13.15q-.625-.125-1.062-.575T3 11.5q0-.65.45-1.075t1.075-.325q1.825.25 3.413 1.063t2.837 2.062t2.063 2.838t1.062 3.412q.1.625-.325 1.075T12.5 21" />
              </svg>
            </span>
          </div>
          <div class="divider"></div>
          <div class="description">
            To subscribe, copy the URL from the address bar and add it to your feed reader.
          </div>

          <div class="footer">
            <span>Last Updated: </span>
            <xsl:variable name="dateStr" select="/rss/channel/lastBuildDate" />
            <xsl:variable name="year" select="substring($dateStr, 13, 4)" />
            <xsl:variable name="month" select="substring($dateStr, 9, 3)" />
            <xsl:variable name="day" select="substring($dateStr, 6, 2)" />
            <xsl:variable name="monthNum">
              <xsl:choose>
                <xsl:when test="$month='Jan'">01</xsl:when>
                <xsl:when test="$month='Feb'">02</xsl:when>
                <xsl:when test="$month='Mar'">03</xsl:when>
                <xsl:when test="$month='Apr'">04</xsl:when>
                <xsl:when test="$month='May'">05</xsl:when>
                <xsl:when test="$month='Jun'">06</xsl:when>
                <xsl:when test="$month='Jul'">07</xsl:when>
                <xsl:when test="$month='Aug'">08</xsl:when>
                <xsl:when test="$month='Sep'">09</xsl:when>
                <xsl:when test="$month='Oct'">10</xsl:when>
                <xsl:when test="$month='Nov'">11</xsl:when>
                <xsl:when test="$month='Dec'">12</xsl:when>
              </xsl:choose>
            </xsl:variable>
            <xsl:value-of select="concat($year, '.', $monthNum, '.', $day)" />
          </div>

        </div>

      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>