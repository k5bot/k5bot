<?xml version="1.0"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template match="/">
    <html>
      <head>
        <style type="text/css">
          h1, h2, h3, h4, h5, h6 {
            font-style: italic;
            margin-top: 1em;
            margin-bottom: 0.5em;
          }
          .padder { padding-left: 1em; }
          .command-cell {
            vertical-align: top;
            font-weight: bold;
          }
          .command-list, .command-list td, .command-list th {
            border: 1px solid black;
            border-collapse:collapse;
            padding: 0.5em;
          }
          .command-list th {
            background-color: #9acd32;
            color: white;
            font-style: italic;
            font-weight: bold;
          }
          a, a:active { color: #006699; }
          a:visited { color: #663333; }
          a:hover { color: #0099ff; }
        </style>
      </head>
      <body>
        <h1>K5 Bot help</h1>
        <ol>
          <xsl:apply-templates select="help/plugins" mode="toc"/>
        </ol>
        <xsl:apply-templates select="help/plugins"/>
      </body>
    </html>
  </xsl:template>

  <xsl:template match="plugin">
    <xsl:variable name="hierarchy_id" select="concat('plugin-', @name)"/>

    <xsl:element name="h2">
      <xsl:attribute name="id"><xsl:value-of select="$hierarchy_id"/></xsl:attribute>
      Plugin '<xsl:value-of select="@name"/>'
    </xsl:element>

    <div class="padder">
      <xsl:apply-templates select="description">
        <xsl:with-param name="hierarchy_id" select="$hierarchy_id"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="commands"/>
      <xsl:apply-templates select="dependencies"/>
    </div>
  </xsl:template>

  <xsl:template match="plugin" mode="toc">
    <xsl:variable name="hierarchy_id" select="concat('plugin-', @name)"/>

    <li>
      <xsl:element name="a">
        <xsl:attribute name="href">#<xsl:value-of select="$hierarchy_id"/></xsl:attribute>
        <xsl:value-of select="@name"/>
      </xsl:element>
      - <xsl:value-of select="description/summary"/>
    </li>

    <ul>
      <xsl:apply-templates select="description" mode="toc">
        <xsl:with-param name="hierarchy_id" select="$hierarchy_id"/>
      </xsl:apply-templates>
    </ul>
    <ol>
      <xsl:apply-templates select="commands" mode="toc"/>
    </ol>
  </xsl:template>

  <xsl:template match="description">
    <xsl:param name="hierarchy_id" />

    <h3>Description</h3>
    <div class="padder">
      <xsl:apply-templates select="*">
        <xsl:with-param name="hierarchy" select="3"/>
        <xsl:with-param name="hierarchy_id" select="$hierarchy_id"/>
      </xsl:apply-templates>
    </div>
  </xsl:template>

  <xsl:template match="description" mode="toc">
    <xsl:param name="hierarchy_id" />

    <!-- only render sections, skip summaries -->
    <xsl:apply-templates select="section" mode="toc">
      <xsl:with-param name="hierarchy" select="3"/>
      <xsl:with-param name="hierarchy_id" select="$hierarchy_id"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="summary">
    <xsl:value-of select="text()"/>
  </xsl:template>
  <!--
  <xsl:template match="summary" mode="toc">
     no summary in toc
  </xsl:template>-->

  <xsl:template match="section">
    <xsl:param name="hierarchy" select="1" />
    <xsl:param name="hierarchy_id" />
    <xsl:variable name="new_id" select="concat($hierarchy_id, '-', @name)"/>

    <xsl:variable name="heading">
      <xsl:choose>
        <xsl:when test="$hierarchy > 6">h6</xsl:when>
        <xsl:otherwise>h<xsl:value-of select="$hierarchy" /></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:element name="{$heading}">
      <xsl:attribute name="id">
        <xsl:value-of select="$new_id" />
      </xsl:attribute>
      <xsl:value-of select="@name" />
    </xsl:element>

    <div class="padder">
      <xsl:apply-templates select="*">
        <xsl:with-param name="hierarchy" select="$hierarchy+1"/>
        <xsl:with-param name="hierarchy_id" select="$new_id"/>
      </xsl:apply-templates>
    </div>
  </xsl:template>

  <xsl:template match="section" mode="toc">
    <xsl:param name="hierarchy" select="1" />
    <xsl:param name="hierarchy_id" />
    <xsl:variable name="new_id" select="concat($hierarchy_id, '-', @name)"/>

    <li>
      <xsl:element name="a">
        <xsl:attribute name="href">#<xsl:value-of select="$new_id"/></xsl:attribute>
        <xsl:value-of select="@name"/>
      </xsl:element>
    </li>

    <ol>
      <!-- only render sections, skip summaries -->
      <xsl:apply-templates select="section" mode="toc">
        <xsl:with-param name="hierarchy" select="$hierarchy+1"/>
        <xsl:with-param name="hierarchy_id" select="$new_id"/>
      </xsl:apply-templates>
    </ol>
  </xsl:template>

  <xsl:template match="commands">
    <h3>Commands</h3>
    <table class="command-list">
      <tr>
        <th>Command</th>
        <th>Description</th>
      </tr>
      <xsl:apply-templates select="command"/>
    </table>
  </xsl:template>

  <xsl:template match="commands" mode="toc">
    <!-- too much information
    <xsl:apply-templates select="command" mode="toc"/>
    -->
  </xsl:template>

  <xsl:template match="command">
    <xsl:variable name="hierarchy_id" select="concat('command-', @name)"/>

    <tr>
      <td class="command-cell">.<xsl:value-of select="@name"/></td>
      <td>
        <xsl:apply-templates select="*">
          <xsl:with-param name="hierarchy" select="3"/>
          <xsl:with-param name="hierarchy_id" select="$hierarchy_id"/>
        </xsl:apply-templates>
      </td>
    </tr>
  </xsl:template>

  <xsl:template match="command" mode="toc">
    <!-- not currently used -->

    <xsl:variable name="hierarchy_id" select="concat('command-', @name)"/>

    <li>
      <xsl:element name="a">
        <xsl:attribute name="href">#<xsl:value-of select="$hierarchy_id"/></xsl:attribute>
        <xsl:value-of select="concat('.', @name)"/>
      </xsl:element>
    </li>

    <ul>
      <xsl:apply-templates select="*" mode="toc">
        <xsl:with-param name="hierarchy" select="3"/>
        <xsl:with-param name="hierarchy_id" select="concat('command-', @name)"/>
      </xsl:apply-templates>
    </ul>
  </xsl:template>

  <xsl:template match="dependencies">
    <h4>Depends on:
      <xsl:for-each select="dep">
        <xsl:variable name="hierarchy_id" select="concat('plugin-', .)"/>

        <xsl:element name="a">
          <xsl:attribute name="href">#<xsl:value-of select="$hierarchy_id"/></xsl:attribute>
          <xsl:value-of select="."/>
        </xsl:element>

        <xsl:if test="position() != last()">
          <xsl:text>, </xsl:text>
        </xsl:if>
      </xsl:for-each>
    </h4>
  </xsl:template>
</xsl:stylesheet>