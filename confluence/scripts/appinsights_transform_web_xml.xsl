<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  xmlns:w="http://xmlns.jcp.org/xml/ns/javaee" exclude-result-prefixes="w">

<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>

<xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="w:filter[w:filter-name='debug-before-request']">
    <xsl:copy>
        <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>

    <xsl:copy-of select="preceding-sibling::text()[1]"/>  

    <filter xmlns="http://xmlns.jcp.org/xml/ns/javaee">
      <filter-name>ApplicationInsightsWebFilter</filter-name>
      <filter-class>com.microsoft.applicationinsights.web.internal.WebRequestTrackingFilter</filter-class>
    </filter>

    <xsl:copy-of select="preceding-sibling::text()[1]"/>  
  </xsl:template>

  <xsl:template match="w:filter-mapping[w:filter-name='debug-before-request']">
    <xsl:copy>
        <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  
    <xsl:copy-of select="preceding-sibling::text()[1]"/>  

    <filter-mapping xmlns="http://xmlns.jcp.org/xml/ns/javaee">
       <filter-name>ApplicationInsightsWebFilter</filter-name>
       <url-pattern>/*</url-pattern>
    </filter-mapping>

    <xsl:copy-of select="preceding-sibling::text()[1]"/>  
  </xsl:template>

</xsl:stylesheet>
