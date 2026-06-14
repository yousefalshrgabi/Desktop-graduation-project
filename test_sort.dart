void main() {
  var l = List.generate(40, (i) => i % 2 == 0 ? i.toString() : '${i}A');
  try {
    l.sort((a,b) { 
      final na=int.tryParse(a.trim()); 
      final nb=int.tryParse(b.trim()); 
      if (na!=null && nb!=null) return na.compareTo(nb); 
      return a.compareTo(b); 
    });
    print('Sorted successfully!');
  } catch (e) {
    print('Sort failed: $e');
  }
}
